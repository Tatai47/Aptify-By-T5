import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aptify_by_t5/main.dart';
import 'package:aptify_by_t5/core/services/system_detection_service.dart';
import 'package:aptify_by_t5/models/environment_status.dart';
import 'package:aptify_by_t5/providers/environment_provider.dart';

class FakeSystemDetectionService extends SystemDetectionService {
  @override
  Future<EnvironmentStatus> detectEnvironment() async {
    return const EnvironmentStatus(
      hasPython: true,
      hasMySQL: true,
      databases: ['aptify_db', 'ecommerce'],
      pythonVersion: 'Python 3.12.0',
    );
  }
}

void main() {
  testWidgets('Aptify by T5 app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemDetectionServiceProvider.overrideWithValue(FakeSystemDetectionService()),
        ],
        child: const AptifyApp(),
      ),
    );

    // Let the initial frame and async provider resolve
    await tester.pumpAndSettle();

    // Verify app title exists in app bar
    expect(find.text('Aptify by T5'), findsOneWidget);

    // Verify local execution engines status card appears
    expect(find.text('Local Execution Engines'), findsOneWidget);

    // Verify practice setup form exists
    expect(find.text('Practice Session Setup'), findsOneWidget);
    expect(find.text('Generate Practice Question'), findsOneWidget);
  });
}
