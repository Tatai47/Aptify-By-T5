import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/diagnostic.dart';
import '../../models/practice_config.dart';
import '../../models/question.dart';

/// Gemini AI Service powering dynamic question generation and AI diagnostics.
///
/// API Key can be supplied via `--dart-define=GEMINI_API_KEY="your_api_key_here"`
/// or dynamically configured at runtime in the app.
class GeminiService {
  // Read compile-time environment variable: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  
  String? _runtimeApiKey;

  GeminiService({String? customApiKey}) : _runtimeApiKey = customApiKey;

  void updateApiKey(String key) {
    _runtimeApiKey = key.trim();
  }

  String get effectiveApiKey {
    if (_runtimeApiKey != null && _runtimeApiKey!.isNotEmpty) {
      return _runtimeApiKey!;
    }
    return _envApiKey;
  }

  bool get hasValidApiKey => effectiveApiKey.isNotEmpty;

  GenerativeModel _getModel() {
    if (!hasValidApiKey) {
      throw StateError(
        'Gemini API Key is missing. Pass it with --dart-define=GEMINI_API_KEY="your_key" '
        'or enter it in the app settings.',
      );
    }
    return GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: effectiveApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        topK: 32,
        topP: 0.95,
      ),
    );
  }

  /// Generates a structured practice challenge based on [config].
  Future<Question> generateQuestion(PracticeConfig config) async {
    // If no API key is provided, return a high-quality built-in challenge as a graceful fallback
    if (!hasValidApiKey) {
      return _getOfflineFallbackQuestion(config);
    }

    final model = _getModel();

    final systemInstruction = '''
You are a strict, world-class technical examiner for ${config.subject}.
Your job is to generate a rigorous, practical, interactive challenge calibrated to Difficulty Level ${config.difficulty} (on a scale of 1 to 5).

Subject: ${config.subject}
Target Database: ${config.targetDatabase.isNotEmpty ? config.targetDatabase : "default"}
Difficulty Level: ${config.difficulty}/5 (1=Beginner, 3=Intermediate, 5=Expert)
Uploaded Syllabus/Reference Context:
${config.uploadedContext.isNotEmpty ? config.uploadedContext : "No additional syllabus provided. Use standard enterprise curriculum for ${config.subject}."}

CRITICAL RULES:
1. You MUST respond with ONLY a valid, parseable JSON object. No explanation text outside JSON.
2. For MySQL challenges:
   - Provide "setup_script": A complete SQL script to CREATE TABLE IF NOT EXISTS and INSERT 3-6 sample rows of realistic test data.
   - Provide "expected_code": The canonical SQL SELECT/query that answers the challenge.
   - Provide "prompt": A clear, unambiguous problem statement detailing what data to retrieve or manipulate, expected ordering, and conditions.
3. For Python challenges:
   - Provide "setup_script": null
   - Provide "expected_code": A self-contained, executable Python script with sample test data and print() outputs.
   - Provide "prompt": A clear problem statement explaining the algorithm, inputs, and expected printed outputs.
4. JSON schema to follow:
{
  "title": "Short descriptive challenge title",
  "prompt": "Full markdown-formatted problem statement",
  "expected_code": "Canonical solution code",
  "setup_script": "Optional DDL/DML script (MySQL only) or null"
}
''';

    try {
      final response = await model.generateContent([
        Content.text(systemInstruction),
      ]);

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      return _parseQuestionJson(text, config);
    } catch (e) {
      // If network fails or quota exceeded, fall back safely
      return _getOfflineFallbackQuestion(config, note: 'Gemini request failed: $e');
    }
  }

  /// Analyzes the discrepancy between user code and baseline expected code.
  Future<Diagnostic> analyzeDiff({
    required String subject,
    required String expectedCode,
    required String userCode,
    required String expectedOutput,
    required String userOutput,
    required String errorMessage,
  }) async {
    if (!hasValidApiKey) {
      return Diagnostic(
        summary: 'Execution Discrepancy Detected',
        detailedExplanation: errorMessage.isNotEmpty
            ? 'Execution failed with runtime/syntax error: $errorMessage'
            : 'Your code output did not match the expected baseline output.\n\nExpected:\n$expectedOutput\n\nYour Output:\n$userOutput',
        logicalFlaws: [
          if (errorMessage.isNotEmpty) 'Error: $errorMessage' else 'Output mismatch with baseline',
        ],
        hints: [
          'Verify variable names, edge cases, and output formatting.',
          'Add GEMINI_API_KEY via --dart-define=GEMINI_API_KEY=YOUR_KEY for detailed AI diagnostics.',
        ],
        isSyntaxError: errorMessage.isNotEmpty,
        rawResponse: 'Offline diagnosis. Configure Gemini API key for deep AI analysis.',
      );
    }

    final model = _getModel();

    final prompt = '''
You are an expert diagnostic programming tutor.
A student just submitted their solution for a $subject challenge.
Their solution did NOT pass or produced different results compared to the canonical solution.

[CANONICAL EXPECTED CODE]:
```
$expectedCode
```

[EXPECTED OUTPUT]:
```
$expectedOutput
```

[STUDENT'S SUBMITTED CODE]:
```
$userCode
```

[STUDENT'S OUTPUT]:
```
$userOutput
```

[STUDENT'S ERROR (IF ANY)]:
```
$errorMessage
```

TUTORING INSTRUCTIONS:
1. Explain WHY the student's code failed, threw an error, or produced different output.
2. Point out specific logical, algorithmic, or syntactic flaws in their thought process.
3. DO NOT give away the exact solution or copy-paste the expected code. Guide them with thought-provoking questions and hints.
4. Structure your response with these clear sections:
   ### Summary
   ### Logical Flaws Identified
   ### Guided Hints (Step-by-step guidance without giving the direct answer)
''';

    try {
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text ?? 'No diagnostic analysis generated.';
      return Diagnostic.fromMarkdownOrText(text, isSyntax: errorMessage.isNotEmpty);
    } catch (e) {
      return Diagnostic(
        summary: 'Diagnostic Analysis Error',
        detailedExplanation: 'Failed to retrieve AI analysis from Gemini: $e\n\n'
            'Your code output was:\n$userOutput\n\n'
            'Expected output was:\n$expectedOutput',
        logicalFlaws: ['AI request failed ($e)'],
        hints: ['Check your internet connection and Gemini API quota.'],
        isSyntaxError: errorMessage.isNotEmpty,
        rawResponse: 'Error: $e',
      );
    }
  }

  /// Extracts and parses the JSON response from Gemini, removing markdown fences.
  Question _parseQuestionJson(String raw, PracticeConfig config) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    try {
      final map = json.decode(cleaned) as Map<String, dynamic>;
      return Question.fromMap(map);
    } catch (_) {
      // Fallback if formatting was malformed
      return Question(
        title: '${config.subject} Level ${config.difficulty} Challenge',
        prompt: raw,
        expectedCode: config.isMySQL
            ? 'SELECT * FROM practice_table;'
            : 'print("Aptify by T5 Practice")',
      );
    }
  }

  /// High-quality built-in starter questions when API key is pending or offline.
  Question _getOfflineFallbackQuestion(PracticeConfig config, {String? note}) {
    final banner = note != null
        ? '> **Notice:** $note\n\n'
        : '> **Tip:** Set your Gemini API key via `--dart-define=GEMINI_API_KEY="your-key"` or in the UI to generate unlimited dynamic challenges!\n\n';

    if (config.isMySQL) {
      return Question(
        title: 'Department Salary Aggregation (Level ${config.difficulty})',
        prompt: '$banner### Problem Statement\n'
            'You are provided with an `employees` table. Write a SQL query to find the department name, the total number of employees in that department, and the average salary rounded to 2 decimal places.\n\n'
            'Filter the results to only include departments that have **more than 1 employee**, and sort the output by `average_salary` in descending order.',
        setupScript: '''
CREATE TABLE IF NOT EXISTS employees (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) NOT NULL
);

DELETE FROM employees;

INSERT INTO employees (name, department, salary) VALUES
('Alice Chen', 'Engineering', 95000.00),
('Bob Martin', 'Engineering', 105000.00),
('Charlie Davis', 'Marketing', 68000.00),
('Diana Prince', 'Engineering', 115000.00),
('Evan Wright', 'Marketing', 72000.00),
('Fiona Gallagher', 'Human Resources', 60000.00);
''',
        expectedCode: '''
SELECT 
    department, 
    COUNT(*) AS total_employees, 
    ROUND(AVG(salary), 2) AS average_salary
FROM employees
GROUP BY department
HAVING COUNT(*) > 1
ORDER BY average_salary DESC;
''',
      );
    } else {
      return Question(
        title: 'Consecutive Subarray Sum Finder (Level ${config.difficulty})',
        prompt: '$banner### Problem Statement\n'
            'Write a Python function `find_subarray_with_sum(nums, target_sum)` that takes a list of integers and a target integer.\n'
            'Return the starting and ending indices (0-indexed, inclusive) of the first contiguous subarray that adds up to `target_sum`.\n'
            'If no such subarray exists, return `None`.\n\n'
            'The test runner evaluates your function on sample inputs and prints the result.',
        setupScript: null,
        expectedCode: '''
def find_subarray_with_sum(nums, target_sum):
    prefix_map = {0: -1}
    current_sum = 0
    for idx, num in enumerate(nums):
        current_sum += num
        diff = current_sum - target_sum
        if diff in prefix_map:
            return (prefix_map[diff] + 1, idx)
        prefix_map[current_sum] = idx
    return None

# Test cases
sample_1 = [1, 4, 20, 3, 10, 5]
print("Result 1:", find_subarray_with_sum(sample_1, 33))

sample_2 = [1, 2, 3, 7, 5]
print("Result 2:", find_subarray_with_sum(sample_2, 12))
''',
      );
    }
  }
}
