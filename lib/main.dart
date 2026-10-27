import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/setup_screen.dart';

/// Aptify by T5 - Interactive Programming Practice Environment
/// for MySQL and Python powered by local execution runtimes and Gemini 1.5 Pro.
///
/// Gemini API Key Injection:
/// Pass via compile-time flag:
///   flutter run -d windows --dart-define=GEMINI_API_KEY="AIzaSy..."
/// or on macOS:
///   flutter run -d macos --dart-define=GEMINI_API_KEY="AIzaSy..."
///
/// Alternatively, the key can be pasted dynamically directly inside the Setup Screen UI.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AptifyApp(),
    ),
  );
}

class AptifyApp extends StatelessWidget {
  const AptifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aptify by T5',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      home: const SetupScreen(),
    );
  }
}
