import 'dart:convert';

/// Configuration for a practice session selected by the user.
class PracticeConfig {
  final String subject; // 'MySQL' or 'Python'
  final String targetDatabase;
  final int difficulty; // 1 to 5
  final String uploadedContext;

  const PracticeConfig({
    required this.subject,
    required this.targetDatabase,
    required this.difficulty,
    required this.uploadedContext,
  });

  factory PracticeConfig.initial() {
    return const PracticeConfig(
      subject: 'Python',
      targetDatabase: '',
      difficulty: 2,
      uploadedContext: '',
    );
  }

  bool get isMySQL => subject.toLowerCase() == 'mysql';
  bool get isPython => subject.toLowerCase() == 'python';

  PracticeConfig copyWith({
    String? subject,
    String? targetDatabase,
    int? difficulty,
    String? uploadedContext,
  }) {
    return PracticeConfig(
      subject: subject ?? this.subject,
      targetDatabase: targetDatabase ?? this.targetDatabase,
      difficulty: difficulty ?? this.difficulty,
      uploadedContext: uploadedContext ?? this.uploadedContext,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'targetDatabase': targetDatabase,
      'difficulty': difficulty,
      'uploadedContext': uploadedContext,
    };
  }

  factory PracticeConfig.fromMap(Map<String, dynamic> map) {
    return PracticeConfig(
      subject: map['subject'] as String? ?? 'Python',
      targetDatabase: map['targetDatabase'] as String? ?? '',
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 2,
      uploadedContext: map['uploadedContext'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory PracticeConfig.fromJson(String source) =>
      PracticeConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'PracticeConfig(subject: $subject, targetDatabase: $targetDatabase, difficulty: $difficulty, contextLen: ${uploadedContext.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PracticeConfig &&
        other.subject == subject &&
        other.targetDatabase == targetDatabase &&
        other.difficulty == difficulty &&
        other.uploadedContext == uploadedContext;
  }

  @override
  int get hashCode => Object.hash(subject, targetDatabase, difficulty, uploadedContext);
}
