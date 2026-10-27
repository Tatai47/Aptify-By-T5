import 'dart:convert';

/// Represents AI-driven diagnostic feedback on code logic, errors, or differences.
class Diagnostic {
  final String summary;
  final String detailedExplanation;
  final List<String> logicalFlaws;
  final List<String> hints;
  final bool isSyntaxError;
  final String rawResponse;

  const Diagnostic({
    required this.summary,
    required this.detailedExplanation,
    required this.logicalFlaws,
    required this.hints,
    this.isSyntaxError = false,
    this.rawResponse = '',
  });

  factory Diagnostic.empty() {
    return const Diagnostic(
      summary: '',
      detailedExplanation: '',
      logicalFlaws: [],
      hints: [],
      isSyntaxError: false,
      rawResponse: '',
    );
  }

  factory Diagnostic.fromMarkdownOrText(String text, {bool isSyntax = false}) {
    // Helper to parse bullet points or sections if formatted
    final lines = text.split('\n');
    final flaws = <String>[];
    final hints = <String>[];
    bool inHints = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().contains('flaw') ||
          trimmed.toLowerCase().contains('issue') ||
          trimmed.toLowerCase().contains('why it failed')) {
        inHints = false;
        continue;
      } else if (trimmed.toLowerCase().contains('hint') ||
          trimmed.toLowerCase().contains('next step') ||
          trimmed.toLowerCase().contains('guide')) {
        inHints = true;
        continue;
      }

      if ((trimmed.startsWith('- ') || trimmed.startsWith('* ') || RegExp(r'^\d+\.').hasMatch(trimmed))) {
        final content = trimmed.replaceFirst(RegExp(r'^[-*]|\d+\.\s*'), '').trim();
        if (content.isNotEmpty) {
          if (inHints) {
            hints.add(content);
          } else {
            flaws.add(content);
          }
        }
      }
    }

    return Diagnostic(
      summary: lines.isNotEmpty ? lines.first.replaceAll('#', '').trim() : 'Analysis Completed',
      detailedExplanation: text,
      logicalFlaws: flaws,
      hints: hints,
      isSyntaxError: isSyntax,
      rawResponse: text,
    );
  }

  Diagnostic copyWith({
    String? summary,
    String? detailedExplanation,
    List<String>? logicalFlaws,
    List<String>? hints,
    bool? isSyntaxError,
    String? rawResponse,
  }) {
    return Diagnostic(
      summary: summary ?? this.summary,
      detailedExplanation: detailedExplanation ?? this.detailedExplanation,
      logicalFlaws: logicalFlaws ?? this.logicalFlaws,
      hints: hints ?? this.hints,
      isSyntaxError: isSyntaxError ?? this.isSyntaxError,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'detailedExplanation': detailedExplanation,
      'logicalFlaws': logicalFlaws,
      'hints': hints,
      'isSyntaxError': isSyntaxError,
      'rawResponse': rawResponse,
    };
  }

  factory Diagnostic.fromMap(Map<String, dynamic> map) {
    return Diagnostic(
      summary: map['summary'] as String? ?? '',
      detailedExplanation: map['detailedExplanation'] as String? ?? '',
      logicalFlaws: List<String>.from(map['logicalFlaws'] as List? ?? []),
      hints: List<String>.from(map['hints'] as List? ?? []),
      isSyntaxError: map['isSyntaxError'] as bool? ?? false,
      rawResponse: map['rawResponse'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Diagnostic.fromJson(String source) =>
      Diagnostic.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Diagnostic(summary: $summary, flaws: ${logicalFlaws.length}, hints: ${hints.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Diagnostic &&
        other.summary == summary &&
        other.detailedExplanation == detailedExplanation &&
        other.isSyntaxError == isSyntaxError &&
        other.rawResponse == rawResponse;
  }

  @override
  int get hashCode => Object.hash(summary, detailedExplanation, isSyntaxError, rawResponse);
}
