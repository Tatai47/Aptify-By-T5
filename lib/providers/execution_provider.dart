import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/mysql_execution_service.dart';
import '../core/services/python_execution_service.dart';
import '../models/diagnostic.dart';
import '../models/execution_result.dart';
import '../models/question.dart';
import 'practice_provider.dart';

enum ExecutionStatus {
  idle,
  runningBaseline,
  runningUserCode,
  analyzingDiff,
  success,
  diagnosticFeedback,
  error,
}

/// State representation for the execution and grading pipeline.
class ExecutionState {
  final ExecutionStatus status;
  final ExecutionResult? userResult;
  final ExecutionResult? baselineResult;
  final Diagnostic? diagnostic;
  final String statusMessage;

  const ExecutionState({
    this.status = ExecutionStatus.idle,
    this.userResult,
    this.baselineResult,
    this.diagnostic,
    this.statusMessage = '',
  });

  bool get isBusy =>
      status == ExecutionStatus.runningBaseline ||
      status == ExecutionStatus.runningUserCode ||
      status == ExecutionStatus.analyzingDiff;

  bool get isSuccess => status == ExecutionStatus.success;

  ExecutionState copyWith({
    ExecutionStatus? status,
    ExecutionResult? userResult,
    ExecutionResult? baselineResult,
    Diagnostic? diagnostic,
    String? statusMessage,
  }) {
    return ExecutionState(
      status: status ?? this.status,
      userResult: userResult ?? this.userResult,
      baselineResult: baselineResult ?? this.baselineResult,
      diagnostic: diagnostic ?? this.diagnostic,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// Providers for Execution Services
final pythonExecutionServiceProvider = Provider<PythonExecutionService>((ref) {
  return PythonExecutionService();
});

final mysqlExecutionServiceProvider = Provider<MysqlExecutionService>((ref) {
  return MysqlExecutionService();
});

/// Notifier handling running code, comparing outputs with baseline, and triggering Gemini diff analysis.
class ExecutionNotifier extends Notifier<ExecutionState> {
  @override
  ExecutionState build() {
    return const ExecutionState();
  }

  void reset() {
    state = const ExecutionState();
  }

  /// Runs the user code locally to observe console output without grading.
  Future<void> runOnly({
    required String userCode,
    required String subject,
    required String targetDatabase,
  }) async {
    state = state.copyWith(
      status: ExecutionStatus.runningUserCode,
      statusMessage: 'Running $subject code locally...',
      diagnostic: null,
    );

    final isMySQL = subject.toLowerCase() == 'mysql';
    ExecutionResult userRes;

    if (isMySQL) {
      final mysqlService = ref.read(mysqlExecutionServiceProvider);
      userRes = await mysqlService.executeQuery(
        query: userCode,
        databaseName: targetDatabase,
      );
    } else {
      final pyService = ref.read(pythonExecutionServiceProvider);
      userRes = await pyService.execute(userCode);
    }

    state = state.copyWith(
      status: userRes.isSuccess ? ExecutionStatus.idle : ExecutionStatus.error,
      userResult: userRes,
      statusMessage: userRes.isSuccess ? 'Executed successfully' : 'Execution encountered an error',
    );
  }

  /// Executes database setup script for MySQL questions.
  Future<ExecutionResult> runSetupScript({
    required String setupScript,
    required String targetDatabase,
  }) async {
    final mysqlService = ref.read(mysqlExecutionServiceProvider);
    return await mysqlService.executeSetupScript(
      setupScript: setupScript,
      databaseName: targetDatabase,
    );
  }

  /// Submits the user code:
  /// 1. Executes expected canonical code to compute baseline output.
  /// 2. Executes user code.
  /// 3. Normalizes and compares outputs.
  /// 4. If exact match: Success.
  /// 5. If discrepancy or error: Calls Gemini to analyze the diff and diagnose.
  Future<void> submitAndEvaluate({
    required String userCode,
    required Question question,
    required String subject,
    required String targetDatabase,
  }) async {
    final isMySQL = subject.toLowerCase() == 'mysql';
    final pyService = ref.read(pythonExecutionServiceProvider);
    final mysqlService = ref.read(mysqlExecutionServiceProvider);
    final geminiService = ref.read(geminiServiceProvider);

    // Optional: Auto-execute setup script for MySQL if provided
    if (isMySQL && question.setupScript != null && question.setupScript!.isNotEmpty) {
      state = state.copyWith(
        status: ExecutionStatus.runningBaseline,
        statusMessage: 'Preparing database schema and test records...',
      );
      await mysqlService.executeSetupScript(
        setupScript: question.setupScript!,
        databaseName: targetDatabase,
      );
    }

    // 1. Run Baseline Expected Code
    state = state.copyWith(
      status: ExecutionStatus.runningBaseline,
      statusMessage: 'Computing canonical baseline output...',
      diagnostic: null,
    );

    ExecutionResult baselineRes;
    if (isMySQL) {
      baselineRes = await mysqlService.executeQuery(
        query: question.expectedCode,
        databaseName: targetDatabase,
      );
    } else {
      baselineRes = await pyService.execute(question.expectedCode);
    }

    // 2. Run User Code
    state = state.copyWith(
      status: ExecutionStatus.runningUserCode,
      baselineResult: baselineRes,
      statusMessage: 'Executing your submitted solution...',
    );

    ExecutionResult userRes;
    if (isMySQL) {
      userRes = await mysqlService.executeQuery(
        query: userCode,
        databaseName: targetDatabase,
      );
    } else {
      userRes = await pyService.execute(userCode);
    }

    // 3. Compare outputs
    final isUserOk = userRes.isSuccess;
    final normalizedBaseline = _normalizeOutput(baselineRes.output);
    final normalizedUser = _normalizeOutput(userRes.output);

    final isMatch = isUserOk && (normalizedBaseline == normalizedUser);

    if (isMatch) {
      state = state.copyWith(
        status: ExecutionStatus.success,
        userResult: userRes,
        baselineResult: baselineRes,
        statusMessage: 'Solution Verified! All outputs match canonical baseline.',
      );
      return;
    }

    // 4. Outputs differ or error occurred -> AI Diagnostic Tutor
    state = state.copyWith(
      status: ExecutionStatus.analyzingDiff,
      userResult: userRes,
      baselineResult: baselineRes,
      statusMessage: 'Requesting AI diagnostic tutor feedback...',
    );

    final diagnostic = await geminiService.analyzeDiff(
      subject: subject,
      expectedCode: question.expectedCode,
      userCode: userCode,
      expectedOutput: baselineRes.output,
      userOutput: userRes.output,
      errorMessage: userRes.errorMessage,
    );

    state = state.copyWith(
      status: ExecutionStatus.diagnosticFeedback,
      diagnostic: diagnostic,
      statusMessage: 'Diagnostic analysis ready',
    );
  }

  /// Normalizes output by trimming whitespace and line breaks for fair comparison.
  String _normalizeOutput(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }
}

/// Global provider for the execution state.
final executionProvider =
    NotifierProvider<ExecutionNotifier, ExecutionState>(
  ExecutionNotifier.new,
);
