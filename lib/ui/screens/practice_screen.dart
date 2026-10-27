import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/sql.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';
import '../../providers/execution_provider.dart';
import '../../providers/practice_provider.dart';
import '../widgets/split_layout_builder.dart';

/// Interactive desktop practice workspace featuring code editor,
/// local execution consoles, output comparator, and Gemini AI diagnostic tutor.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> with SingleTickerProviderStateMixin {
  late final CodeController _codeController;
  late final TabController _tabController;
  bool _showSetupScript = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final session = ref.read(practiceSessionProvider);
    final isMySQL = session.config.isMySQL;

    final initialCode = session.userCodeDraft ??
        (isMySQL ? '-- Write your MySQL query here\nSELECT ' : '# Write your Python solution here\n');

    _codeController = CodeController(
      text: initialCode,
      language: isMySQL ? sql : python,
    );

    _codeController.addListener(() {
      ref.read(practiceSessionProvider.notifier).updateDraft(_codeController.text);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRunLocally() async {
    final session = ref.read(practiceSessionProvider);
    _tabController.animateTo(0); // Switch to Console Tab

    await ref.read(executionProvider.notifier).runOnly(
          userCode: _codeController.text,
          subject: session.config.subject,
          targetDatabase: session.config.targetDatabase,
        );
  }

  Future<void> _handleSubmitAndGrade() async {
    final session = ref.read(practiceSessionProvider);
    final question = session.currentQuestion;
    if (question == null) return;

    await ref.read(executionProvider.notifier).submitAndEvaluate(
          userCode: _codeController.text,
          question: question,
          subject: session.config.subject,
          targetDatabase: session.config.targetDatabase,
        );

    final execState = ref.read(executionProvider);
    if (!mounted) return;

    // Switch tab automatically based on result
    if (execState.isSuccess) {
      _tabController.animateTo(0); // Console (shows success)
    } else if (execState.diagnostic != null) {
      _tabController.animateTo(1); // AI Diagnostics Tab
    }
  }

  Future<void> _handleRunSetupScript(Question question, String databaseName) async {
    if (question.setupScript == null || question.setupScript!.isEmpty) return;

    setState(() => _isResetting = true);
    final result = await ref.read(executionProvider.notifier).runSetupScript(
          setupScript: question.setupScript!,
          targetDatabase: databaseName,
        );
    setState(() => _isResetting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.output.isNotEmpty ? result.output : result.errorMessage),
          backgroundColor: result.isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(practiceSessionProvider);
    final execState = ref.watch(executionProvider);
    final question = session.currentQuestion;

    if (question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Workspace')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active question found. Please return to setup.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Setup'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              tooltip: 'Return to Setup',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Text(
              question.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            _buildBadge(session.config.subject, AppTheme.primaryColor),
            const SizedBox(width: 8),
            _buildBadge('Level ${session.config.difficulty}', AppTheme.secondaryColor),
            if (session.config.isMySQL && session.config.targetDatabase.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildBadge('DB: ${session.config.targetDatabase}', const Color(0xFF6B7280)),
            ],
          ],
        ),
        actions: [
          if (session.config.isMySQL && question.setupScript != null)
            TextButton.icon(
              onPressed: _isResetting
                  ? null
                  : () => _handleRunSetupScript(question, session.config.targetDatabase),
              icon: _isResetting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                    )
                  : const Icon(Icons.restore_page_rounded, size: 18),
              label: const Text('Reset Schema'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryLight),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SplitLayoutBuilder(
        initialRatio: 0.54,
        leftChild: _buildLeftEditorPanel(session, question, execState),
        rightChild: _buildRightOutputPanel(execState),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // -------------------------------------------------------------
  // LEFT PANEL: Problem Prompt + CodeField + Action Controls
  // -------------------------------------------------------------
  Widget _buildLeftEditorPanel(
    PracticeSessionState session,
    Question question,
    ExecutionState execState,
  ) {
    return Container(
      color: AppTheme.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Question Prompt Section
          _buildPromptHeader(question, session),

          const Divider(height: 1),

          // 2. Code Editor Field
          Expanded(
            child: Container(
              color: AppTheme.darkCodeBackground,
              child: CodeTheme(
                data: CodeThemeData(styles: atomOneDarkTheme),
                child: CodeField(
                  controller: _codeController,
                  textStyle: const TextStyle(
                    fontFamily: 'Consolas, "Fira Code", monospace',
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                  gutterStyle: const GutterStyle(
                    width: 52,
                    textAlign: TextAlign.right,
                    margin: 8,
                    textStyle: TextStyle(
                      fontFamily: 'Consolas, monospace',
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                  expands: true,
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // 3. Execution Control Bar
          _buildEditorBottomBar(execState),
        ],
      ),
    );
  }

  Widget _buildPromptHeader(Question question, PracticeSessionState session) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_outlined, size: 18, color: AppTheme.primaryLight),
                  SizedBox(width: 8),
                  Text(
                    'Problem Statement',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
              if (question.setupScript != null && question.setupScript!.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _showSetupScript = !_showSetupScript),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          _showSetupScript ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showSetupScript ? 'Hide Schema Setup' : 'View Schema Setup',
                          style: const TextStyle(fontSize: 11, color: AppTheme.secondaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: SelectableText(
                question.prompt,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            ),
          ),
          if (_showSetupScript && question.setupScript != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.darkCodeBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: SelectableText(
                question.setupScript!,
                style: const TextStyle(
                  fontFamily: 'Consolas, monospace',
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorBottomBar(ExecutionState execState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.darkSurface,
      child: Row(
        children: [
          // Reset Draft Button
          OutlinedButton.icon(
            onPressed: execState.isBusy
                ? null
                : () {
                    _codeController.text = '';
                  },
            icon: const Icon(Icons.clear_all_rounded, size: 16),
            label: const Text('Clear'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: AppTheme.darkTextSecondary,
              side: const BorderSide(color: AppTheme.darkBorder),
            ),
          ),
          const SizedBox(width: 10),

          // Run Locally (dry run)
          OutlinedButton.icon(
            onPressed: execState.isBusy ? null : _handleRunLocally,
            icon: const Icon(Icons.terminal_rounded, size: 16),
            label: const Text('Run Locally'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),

          const Spacer(),

          // Status Progress or Message
          if (execState.isBusy) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
            ),
            const SizedBox(width: 8),
            Text(
              execState.statusMessage,
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryLight),
            ),
            const SizedBox(width: 14),
          ],

          // Submit & Grade Button
          ElevatedButton.icon(
            onPressed: execState.isBusy ? null : _handleSubmitAndGrade,
            icon: execState.isBusy
                ? const SizedBox.shrink()
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(execState.isBusy ? 'Evaluating...' : 'Run / Submit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RIGHT PANEL: Tabbed Output Console, AI Diagnostics, Diff
  // -------------------------------------------------------------
  Widget _buildRightOutputPanel(ExecutionState execState) {
    return Container(
      color: AppTheme.darkSurfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Header Bar
          Container(
            color: AppTheme.darkSurface,
            child: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(
                  icon: Icon(Icons.terminal_rounded, size: 18),
                  text: 'Console Output',
                ),
                Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 6),
                      const Text('AI Diagnostics'),
                      if (execState.diagnostic != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  icon: Icon(Icons.compare_arrows_rounded, size: 18),
                  text: 'Output Diff',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConsoleTab(execState),
                _buildDiagnosticsTab(execState),
                _buildDiffTab(execState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleTab(ExecutionState execState) {
    final result = execState.userResult;

    if (result == null && !execState.isBusy) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.code_rounded, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            const Text(
              'No execution output yet',
              style: TextStyle(fontSize: 15, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click "Run Locally" or "Run / Submit" to execute your code.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    final isSuccess = execState.isSuccess || (result != null && result.isSuccess);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Banner
        if (result != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isSuccess
                ? AppTheme.successGreen.withAlpha(38)
                : AppTheme.errorRed.withAlpha(38),
            child: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 18,
                  color: isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    execState.status == ExecutionStatus.success
                        ? 'PASSED: Output strictly matches canonical solution.'
                        : (result.isSuccess
                            ? 'Executed Successfully (${result.executionTimeMs}ms)'
                            : 'Execution Error encountered (${result.executionTimeMs}ms)'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSuccess ? AppTheme.successGreen : AppTheme.errorRed,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Output',
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: result.output.isNotEmpty ? result.output : result.errorMessage,
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Console output copied to clipboard.')),
                    );
                  },
                ),
              ],
            ),
          ),

        // Console Output Body
        Expanded(
          child: Container(
            color: AppTheme.darkCodeBackground,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                result != null
                    ? (result.output.isNotEmpty ? result.output : result.errorMessage)
                    : (execState.isBusy ? 'Executing...' : ''),
                style: TextStyle(
                  fontFamily: 'Consolas, monospace',
                  fontSize: 13,
                  height: 1.5,
                  color: (result != null && !result.isSuccess)
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsTab(ExecutionState execState) {
    final diag = execState.diagnostic;

    if (diag == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            const Text(
              'No Diagnostic Feedback Needed',
              style: TextStyle(fontSize: 15, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Submit a solution that encounters errors or differences\n'
              'to receive Gemini 1.5 Pro tutoring and guided hints.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diagnostic Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryLight.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: AppTheme.primaryLight, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gemini 1.5 Pro Diagnostic Tutor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diag.summary,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFC7D2FE)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Identified Logical Flaws
          if (diag.logicalFlaws.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 18),
                SizedBox(width: 8),
                Text(
                  'Identified Flaws & Issues',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...diag.logicalFlaws.map((flaw) => Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppTheme.warningOrange, fontSize: 16)),
                      Expanded(
                        child: Text(
                          flaw,
                          style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.darkTextPrimary),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
          ],

          // Guided Hints (Non-spoiler)
          if (diag.hints.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppTheme.secondaryColor, size: 18),
                SizedBox(width: 8),
                Text(
                  'Guided Hints (Without Spoiling the Answer)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...diag.hints.map((hint) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded, color: AppTheme.secondaryColor, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hint,
                          style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
          ],

          // Full Tutor Analysis
          const Row(
            children: [
              Icon(Icons.description_outlined, color: AppTheme.primaryLight, size: 18),
              SizedBox(width: 8),
              Text(
                'Full Tutor Analysis',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCodeBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: SelectableText(
              diag.detailedExplanation,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFD1D5DB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffTab(ExecutionState execState) {
    final baseline = execState.baselineResult?.output ?? '(No baseline output computed)';
    final userOut = execState.userResult?.output ??
        (execState.userResult?.errorMessage.isNotEmpty == true
            ? execState.userResult!.errorMessage
            : '(No user output yet)');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Baseline vs. User Output Comparison',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Baseline Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: AppTheme.darkSurface,
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Canonical Baseline Output',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: AppTheme.darkCodeBackground,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              baseline,
                              style: const TextStyle(
                                fontFamily: 'Consolas, monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // User Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: AppTheme.darkSurface,
                        child: Row(
                          children: [
                            Icon(
                              execState.isSuccess ? Icons.check_circle_rounded : Icons.info_outline,
                              color: execState.isSuccess ? AppTheme.successGreen : AppTheme.secondaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Your Output',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: AppTheme.darkCodeBackground,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              userOut,
                              style: TextStyle(
                                fontFamily: 'Consolas, monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: execState.isSuccess
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
