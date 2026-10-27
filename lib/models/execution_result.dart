import 'dart:convert';

/// Represents the output of running user or baseline code locally.
class ExecutionResult {
  final String output;
  final bool isSuccess;
  final String errorMessage;
  final int executionTimeMs;

  const ExecutionResult({
    required this.output,
    required this.isSuccess,
    this.errorMessage = '',
    this.executionTimeMs = 0,
  });

  factory ExecutionResult.empty() {
    return const ExecutionResult(
      output: '',
      isSuccess: false,
      errorMessage: '',
      executionTimeMs: 0,
    );
  }

  factory ExecutionResult.success(String output, {int executionTimeMs = 0}) {
    return ExecutionResult(
      output: output,
      isSuccess: true,
      errorMessage: '',
      executionTimeMs: executionTimeMs,
    );
  }

  factory ExecutionResult.failure(String errorMessage, {String output = '', int executionTimeMs = 0}) {
    return ExecutionResult(
      output: output,
      isSuccess: false,
      errorMessage: errorMessage,
      executionTimeMs: executionTimeMs,
    );
  }

  ExecutionResult copyWith({
    String? output,
    bool? isSuccess,
    String? errorMessage,
    int? executionTimeMs,
  }) {
    return ExecutionResult(
      output: output ?? this.output,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'output': output,
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
      'executionTimeMs': executionTimeMs,
    };
  }

  factory ExecutionResult.fromMap(Map<String, dynamic> map) {
    return ExecutionResult(
      output: map['output'] as String? ?? '',
      isSuccess: map['isSuccess'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String? ?? '',
      executionTimeMs: (map['executionTimeMs'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory ExecutionResult.fromJson(String source) =>
      ExecutionResult.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ExecutionResult(isSuccess: $isSuccess, time: ${executionTimeMs}ms, error: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExecutionResult &&
        other.output == output &&
        other.isSuccess == isSuccess &&
        other.errorMessage == errorMessage &&
        other.executionTimeMs == executionTimeMs;
  }

  @override
  int get hashCode => Object.hash(output, isSuccess, errorMessage, executionTimeMs);
}
