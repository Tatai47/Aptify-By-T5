import 'dart:async';
import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import '../../models/environment_status.dart';

/// Service responsible for scanning the local machine for Python and MySQL runtimes.
class SystemDetectionService {
  final String mysqlHost;
  final int mysqlPort;
  final String mysqlUser;
  final String mysqlPassword;

  SystemDetectionService({
    this.mysqlHost = '127.0.0.1',
    this.mysqlPort = 3306,
    this.mysqlUser = 'root',
    this.mysqlPassword = '',
  });

  /// Detects Python runtime on the local machine.
  /// Checks `python` first, then falls back to `python3`.
  Future<Map<String, dynamic>> checkPython() async {
    // 1. Try 'python'
    try {
      final result = await Process.run('python', ['--version']).timeout(
        const Duration(seconds: 4),
        onTimeout: () => ProcessResult(-1, -1, '', 'Timed out checking python'),
      );
      if (result.exitCode == 0) {
        final version = (result.stdout.toString().trim().isNotEmpty)
            ? result.stdout.toString().trim()
            : result.stderr.toString().trim();
        return {'hasPython': true, 'version': version, 'command': 'python'};
      }
    } catch (_) {
      // Fallback to checking python3
    }

    // 2. Try 'python3'
    try {
      final result = await Process.run('python3', ['--version']).timeout(
        const Duration(seconds: 4),
        onTimeout: () => ProcessResult(-1, -1, '', 'Timed out checking python3'),
      );
      if (result.exitCode == 0) {
        final version = (result.stdout.toString().trim().isNotEmpty)
            ? result.stdout.toString().trim()
            : result.stderr.toString().trim();
        return {'hasPython': true, 'version': version, 'command': 'python3'};
      }
    } catch (_) {
      // Ignore
    }

    return {'hasPython': false, 'version': null, 'command': null};
  }

  /// Detects MySQL server running on localhost (127.0.0.1:3306).
  /// If connected, queries `SHOW DATABASES;` and returns database names.
  Future<Map<String, dynamic>> checkMySQL() async {
    MySQLConnection? conn;
    try {
      conn = await MySQLConnection.createConnection(
        host: mysqlHost,
        port: mysqlPort,
        userName: mysqlUser,
        password: mysqlPassword,
        secure: false,
      );

      // Connect with a 4-second timeout to prevent UI hanging if port is closed
      await conn.connect().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          throw TimeoutException('Connection to MySQL on $mysqlHost:$mysqlPort timed out');
        },
      );

      final result = await conn.execute('SHOW DATABASES;');
      final databases = <String>[];

      for (final row in result.rows) {
        final dbName = row.colAt(0);
        if (dbName != null && dbName.isNotEmpty) {
          // Exclude internal MySQL administrative tables from common practice list
          databases.add(dbName);
        }
      }

      await conn.close();

      return {
        'hasMySQL': true,
        'databases': databases,
        'details': '$mysqlHost:$mysqlPort ($mysqlUser)',
      };
    } catch (e) {
      if (conn != null) {
        try {
          await conn.close();
        } catch (_) {}
      }
      return {
        'hasMySQL': false,
        'databases': <String>[],
        'details': e.toString(),
      };
    }
  }

  /// Full environment detection scan.
  Future<EnvironmentStatus> detectEnvironment() async {
    final pythonFuture = checkPython();
    final mysqlFuture = checkMySQL();

    final results = await Future.wait([pythonFuture, mysqlFuture]);
    final pyResult = results[0];
    final myResult = results[1];

    final hasPython = pyResult['hasPython'] as bool? ?? false;
    final pythonVersion = pyResult['version'] as String?;
    final hasMySQL = myResult['hasMySQL'] as bool? ?? false;
    final databases = List<String>.from(myResult['databases'] as List? ?? []);
    final mysqlDetails = myResult['details'] as String?;

    return EnvironmentStatus(
      hasPython: hasPython,
      hasMySQL: hasMySQL,
      databases: databases,
      pythonVersion: pythonVersion,
      mysqlDetails: mysqlDetails,
    );
  }
}
