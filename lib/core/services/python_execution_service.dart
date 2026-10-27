import 'dart:async';
import 'dart:io';
import '../../models/execution_result.dart';

/// Service for executing Python code locally in an isolated subprocess.
class PythonExecutionService {
  final String pythonExecutable;

  PythonExecutionService({this.pythonExecutable = 'python'});

  /// Executes [code] in a temporary Python file and returns the result.
  Future<ExecutionResult> execute(String code, {Duration timeout = const Duration(seconds: 15)}) async {
    final stopwatch = Stopwatch()..start();
    File? tempFile;

    try {
      // 1. Create a temporary script file in the system temp directory
      final tempDir = Directory.systemTemp;
      final fileName = 'aptify_script_${DateTime.now().microsecondsSinceEpoch}.py';
      tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      
      await tempFile.writeAsString(code);

      // 2. Execute with the designated python command
      // Try configured executable, fallback to 'python3' if 'python' fails to spawn
      ProcessResult result;
      try {
        result = await Process.run(
          pythonExecutable,
          [tempFile.path],
        ).timeout(timeout, onTimeout: () {
          throw TimeoutException('Execution timed out after ${timeout.inSeconds} seconds. Check for infinite loops.');
        });
      } on SocketException catch (_) {
        // Retry with python3 if python wasn't found
        result = await Process.run(
          'python3',
          [tempFile.path],
        ).timeout(timeout, onTimeout: () {
          throw TimeoutException('Execution timed out after ${timeout.inSeconds} seconds.');
        });
      }

      stopwatch.stop();

      final stdoutText = result.stdout.toString();
      final stderrText = result.stderr.toString();

      if (result.exitCode == 0) {
        return ExecutionResult.success(
          stdoutText.isNotEmpty ? stdoutText : '(Code executed successfully with no output)',
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return ExecutionResult.failure(
          stderrText.isNotEmpty ? stderrText : 'Process exited with error code ${result.exitCode}',
          output: stdoutText,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
    } on TimeoutException catch (e) {
      stopwatch.stop();
      return ExecutionResult.failure(
        e.message ?? 'Execution timed out',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult.failure(
        'Failed to launch Python execution engine: $e',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      // Clean up the temporary file
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
  }
}
