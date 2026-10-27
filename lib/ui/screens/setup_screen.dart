import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/environment_status.dart';
import '../../providers/environment_provider.dart';
import '../../providers/practice_provider.dart';
import '../widgets/status_indicator.dart';
import 'practice_screen.dart';

/// The Setup and Configuration Screen where users check system runtimes,
/// configure practice parameters (subject, database, difficulty, syllabus),
/// and trigger Gemini-driven challenge generation.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  String? _selectedFileName;
  bool _isUploading = false;
  bool _showApiKeyDialog = false;

  @override
  void initState() {
    super.initState();
    // Initialize API key from provider if configured
    final gemini = ref.read(geminiServiceProvider);
    if (gemini.effectiveApiKey.isNotEmpty) {
      _apiKeyController.text = gemini.effectiveApiKey;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _pickMaterialFile() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql', 'py', 'txt', 'md', 'json', 'csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        String content = '';

        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          content = await file.readAsString();
        } else if (platformFile.bytes != null) {
          content = String.fromCharCodes(platformFile.bytes!);
        }

        setState(() {
          _selectedFileName = platformFile.name;
          _contextController.text = content;
        });

        ref.read(practiceSessionProvider.notifier).updateUploadedContext(content);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded ${_selectedFileName!} (${content.length} characters)'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _generateAndStartPractice() async {
    final practiceNotifier = ref.read(practiceSessionProvider.notifier);
    
    // Save any typed context
    practiceNotifier.updateUploadedContext(_contextController.text);

    // Save API key if typed
    if (_apiKeyController.text.trim().isNotEmpty) {
      practiceNotifier.setApiKey(_apiKeyController.text.trim());
    }

    final question = await practiceNotifier.generateQuestion();

    if (!mounted) return;

    if (question != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PracticeScreen(),
        ),
      );
    } else {
      final error = ref.read(practiceSessionProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to generate challenge. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  String _getDifficultyLabel(int level) {
    switch (level) {
      case 1:
        return 'Level 1: Foundational';
      case 2:
        return 'Level 2: Elementary';
      case 3:
        return 'Level 3: Intermediate';
      case 4:
        return 'Level 4: Advanced';
      case 5:
        return 'Level 5: Master / Production';
      default:
        return 'Level $level';
    }
  }

  @override
  Widget build(BuildContext context) {
    final envAsync = ref.watch(environmentProvider);
    final sessionState = ref.watch(practiceSessionProvider);
    final geminiService = ref.watch(geminiServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.terminal_rounded, color: AppTheme.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Aptify by T5',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v1.0 Desktop',
                style: TextStyle(fontSize: 11, color: AppTheme.secondaryColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configure Gemini API Key',
            icon: Icon(
              geminiService.hasValidApiKey ? Icons.key_rounded : Icons.key_off_rounded,
              color: geminiService.hasValidApiKey ? AppTheme.successGreen : AppTheme.warningOrange,
            ),
            onPressed: () => setState(() => _showApiKeyDialog = !_showApiKeyDialog),
          ),
          IconButton(
            tooltip: 'Rescan System Runtimes',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(environmentProvider.notifier).rescan(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. System Detection Status Bar
                _buildSystemStatusBar(envAsync),

                const SizedBox(height: 24),

                // API Key banner if not configured
                if (!geminiService.hasValidApiKey || _showApiKeyDialog)
                  _buildApiKeyBanner(),

                const SizedBox(height: 24),

                // 2. Practice Configuration Card
                _buildConfigurationCard(envAsync, sessionState),

                const SizedBox(height: 28),

                // 3. Action Button
                _buildActionSubmitButton(sessionState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusBar(AsyncValue<EnvironmentStatus> envAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, size: 20, color: AppTheme.primaryLight),
                    SizedBox(width: 8),
                    Text(
                      'Local Execution Engines',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                if (envAsync.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            envAsync.when(
              data: (status) => Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  StatusIndicator(
                    label: 'Python Engine',
                    isOnline: status.hasPython,
                    subtitle: status.pythonVersion ?? 'Not found in PATH',
                    tooltip: status.hasPython
                        ? 'Python executable ready for subprocess execution.'
                        : 'Please install Python 3 and add to system PATH.',
                  ),
                  StatusIndicator(
                    label: 'MySQL Localhost',
                    isOnline: status.hasMySQL,
                    subtitle: status.hasMySQL
                        ? '127.0.0.1:3306 (${status.databases.length} DBs)'
                        : 'Port 3306 unreachable',
                    tooltip: status.hasMySQL
                        ? 'Available databases: ${status.databases.join(", ")}'
                        : 'Ensure MySQL is running on localhost:3306 with user root.',
                  ),
                ],
              ),
              loading: () => const Text(
                'Scanning local system for Python and MySQL runtimes...',
                style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
              ),
              error: (err, _) => Text(
                'Error scanning environment: $err',
                style: const TextStyle(fontSize: 13, color: AppTheme.errorRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyBanner() {
    return Card(
      color: const Color(0xFF1E1B4B),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.secondaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Gemini 1.5 Pro AI Engine',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Powers strict question generation and AI-driven diagnostic feedback. '
              'You can pass the key via --dart-define=GEMINI_API_KEY="AIza..." or enter it below:',
              style: TextStyle(fontSize: 13, color: Color(0xFFC7D2FE)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter your Gemini API key (AIzaSy...)',
                      prefixIcon: Icon(Icons.key, size: 20),
                    ),
                    onChanged: (val) {
                      ref.read(geminiServiceProvider).updateApiKey(val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(geminiServiceProvider).updateApiKey(_apiKeyController.text.trim());
                    setState(() => _showApiKeyDialog = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gemini API Key saved for this session.'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Key'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard(
    AsyncValue<EnvironmentStatus> envAsync,
    PracticeSessionState sessionState,
  ) {
    final status = envAsync.valueOrNull ?? EnvironmentStatus.initial();
    final isMySQL = sessionState.config.isMySQL;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Practice Session Setup',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),

            // Subject Selector Dropdown
            const Text(
              'Target Subject',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: sessionState.config.subject,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.code_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'Python', child: Text('Python 3.x (Local Runtime)')),
                DropdownMenuItem(value: 'MySQL', child: Text('MySQL (Local Database)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(practiceSessionProvider.notifier).updateSubject(val);
                }
              },
            ),

            // If MySQL is selected, show Database Selector
            if (isMySQL) ...[
              const SizedBox(height: 20),
              const Text(
                'Target MySQL Database',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkTextSecondary),
              ),
              const SizedBox(height: 8),
              if (status.databases.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: status.databases.contains(sessionState.config.targetDatabase)
                      ? sessionState.config.targetDatabase
                      : status.databases.first,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.storage_rounded),
                  ),
                  items: status.databases.map((db) {
                    return DropdownMenuItem(value: db, child: Text(db));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(practiceSessionProvider.notifier).updateTargetDatabase(val);
                    }
                  },
                )
              else
                TextFormField(
                  initialValue: sessionState.config.targetDatabase.isNotEmpty
                      ? sessionState.config.targetDatabase
                      : 'aptify_db',
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.storage_rounded),
                    hintText: 'e.g. test, aptify_db',
                    helperText: 'MySQL not detected or no databases found. Enter target schema name.',
                  ),
                  onChanged: (val) {
                    ref.read(practiceSessionProvider.notifier).updateTargetDatabase(val);
                  },
                ),
            ],

            const SizedBox(height: 24),

            // Difficulty Slider (1 to 5)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Difficulty Level',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkTextSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(38),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getDifficultyLabel(sessionState.config.difficulty),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                thumbColor: AppTheme.primaryLight,
                overlayColor: AppTheme.primaryColor.withAlpha(51),
                valueIndicatorColor: AppTheme.primaryColor,
              ),
              child: Slider(
                value: sessionState.config.difficulty.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: 'Level ${sessionState.config.difficulty}',
                onChanged: (val) {
                  ref.read(practiceSessionProvider.notifier).updateDifficulty(val.round());
                },
              ),
            ),

            const SizedBox(height: 18),

            // Upload Context / Syllabus Material
            const Text(
              'Custom Study Material / Syllabus (Optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickMaterialFile,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(_isUploading ? 'Reading file...' : 'Upload File (.sql, .py, .txt, .md)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkSurfaceElevated,
                    foregroundColor: AppTheme.primaryLight,
                    side: const BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedFileName != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _selectedFileName!,
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contextController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Or paste syllabus topics, table definitions, or concepts to focus on...',
              ),
              onChanged: (val) {
                ref.read(practiceSessionProvider.notifier).updateUploadedContext(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSubmitButton(PracticeSessionState sessionState) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: sessionState.isGenerating ? null : _generateAndStartPractice,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: sessionState.isGenerating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Generating Rigorous Challenge with Gemini 1.5 Pro...',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Generate Practice Question',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
