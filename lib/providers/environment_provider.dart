import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/system_detection_service.dart';
import '../models/environment_status.dart';

/// Provider for the [SystemDetectionService].
final systemDetectionServiceProvider = Provider<SystemDetectionService>((ref) {
  return SystemDetectionService();
});

/// AsyncNotifier that scans local system dependencies (Python & MySQL)
/// and exposes the current [EnvironmentStatus].
class EnvironmentNotifier extends AsyncNotifier<EnvironmentStatus> {
  @override
  Future<EnvironmentStatus> build() async {
    final service = ref.read(systemDetectionServiceProvider);
    return await service.detectEnvironment();
  }

  /// Triggers a manual rescan of local environment runtimes.
  Future<void> rescan({String? host, int? port, String? user, String? password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = SystemDetectionService(
        mysqlHost: host ?? '127.0.0.1',
        mysqlPort: port ?? 3306,
        mysqlUser: user ?? 'root',
        mysqlPassword: password ?? '',
      );
      return await service.detectEnvironment();
    });
  }
}

/// Global provider for the environment status.
final environmentProvider =
    AsyncNotifierProvider<EnvironmentNotifier, EnvironmentStatus>(
  EnvironmentNotifier.new,
);
