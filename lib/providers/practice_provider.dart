import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/gemini_service.dart';
import '../models/practice_config.dart';
import '../models/question.dart';

/// Provider for the [GeminiService] singleton.
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// State representation for the practice session setup and active challenge.
class PracticeSessionState {
  final PracticeConfig config;
  final Question? currentQuestion;
  final bool isGenerating;
  final String? errorMessage;
  final String? userCodeDraft;
  final bool isSetupScriptExecuted;

  const PracticeSessionState({
    required this.config,
    this.currentQuestion,
    this.isGenerating = false,
    this.errorMessage,
    this.userCodeDraft,
    this.isSetupScriptExecuted = false,
  });

  PracticeSessionState copyWith({
    PracticeConfig? config,
    Question? currentQuestion,
    bool? isGenerating,
    String? errorMessage,
    String? userCodeDraft,
    bool? isSetupScriptExecuted,
  }) {
    return PracticeSessionState(
      config: config ?? this.config,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage,
      userCodeDraft: userCodeDraft ?? this.userCodeDraft,
      isSetupScriptExecuted: isSetupScriptExecuted ?? this.isSetupScriptExecuted,
    );
  }
}

/// Notifier managing practice setup, question generation, and active question state.
class PracticeSessionNotifier extends Notifier<PracticeSessionState> {
  @override
  PracticeSessionState build() {
    return PracticeSessionState(
      config: PracticeConfig.initial(),
    );
  }

  void updateSubject(String subject) {
    state = state.copyWith(
      config: state.config.copyWith(subject: subject),
    );
  }

  void updateTargetDatabase(String dbName) {
    state = state.copyWith(
      config: state.config.copyWith(targetDatabase: dbName),
    );
  }

  void updateDifficulty(int difficulty) {
    state = state.copyWith(
      config: state.config.copyWith(difficulty: difficulty),
    );
  }

  void updateUploadedContext(String context) {
    state = state.copyWith(
      config: state.config.copyWith(uploadedContext: context),
    );
  }

  void updateDraft(String code) {
    state = state.copyWith(userCodeDraft: code);
  }

  void setSetupScriptExecuted(bool value) {
    state = state.copyWith(isSetupScriptExecuted: value);
  }

  void setApiKey(String key) {
    ref.read(geminiServiceProvider).updateApiKey(key);
  }

  /// Requests Gemini to generate a dynamic question calibrated to current config.
  Future<Question?> generateQuestion() async {
    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      final gemini = ref.read(geminiServiceProvider);
      final question = await gemini.generateQuestion(state.config);

      // Default user code template based on language
      final initialDraft = state.config.isMySQL
          ? '-- Write your MySQL query here\nSELECT '
          : '# Write your Python solution here\n';

      state = state.copyWith(
        currentQuestion: question,
        isGenerating: false,
        userCodeDraft: initialDraft,
        isSetupScriptExecuted: false,
      );
      return question;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to generate challenge: $e',
      );
      return null;
    }
  }
}

/// Global provider for the practice session.
final practiceSessionProvider =
    NotifierProvider<PracticeSessionNotifier, PracticeSessionState>(
  PracticeSessionNotifier.new,
);
