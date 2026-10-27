import 'dart:convert';

/// Represents a dynamically generated programming challenge from Gemini.
class Question {
  final String prompt;
  final String expectedCode;
  final String? setupScript; // Schema creation/population script for MySQL
  final String title;

  const Question({
    required this.prompt,
    required this.expectedCode,
    this.setupScript,
    this.title = 'Practice Challenge',
  });

  Question copyWith({
    String? prompt,
    String? expectedCode,
    String? setupScript,
    String? title,
  }) {
    return Question(
      prompt: prompt ?? this.prompt,
      expectedCode: expectedCode ?? this.expectedCode,
      setupScript: setupScript ?? this.setupScript,
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'expected_code': expectedCode,
      'setup_script': setupScript,
      'title': title,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      prompt: map['prompt'] as String? ?? '',
      expectedCode: (map['expected_code'] ?? map['expectedCode']) as String? ?? '',
      setupScript: (map['setup_script'] ?? map['setupScript']) as String?,
      title: map['title'] as String? ?? 'Practice Challenge',
    );
  }

  String toJson() => json.encode(toMap());

  factory Question.fromJson(String source) =>
      Question.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Question(title: $title, prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}, hasSetup: ${setupScript != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Question &&
        other.prompt == prompt &&
        other.expectedCode == expectedCode &&
        other.setupScript == setupScript &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(prompt, expectedCode, setupScript, title);
}
