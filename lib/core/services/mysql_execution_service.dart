import 'dart:async';
import 'package:mysql_client/exception.dart';
import 'package:mysql_client/mysql_client.dart';
import '../../models/execution_result.dart';

/// Service for executing SQL queries on a local MySQL instance.
class MysqlExecutionService {
  final String host;
  final int port;
  final String userName;
  final String password;

  MysqlExecutionService({
    this.host = '127.0.0.1',
    this.port = 3306,
    this.userName = 'root',
    this.password = '',
  });

  /// Executes [query] on the specified [databaseName].
  /// Formats the [ResultSet] into a clean ASCII table.
  Future<ExecutionResult> executeQuery({
    required String query,
    required String databaseName,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final stopwatch = Stopwatch()..start();
    MySQLConnection? conn;

    try {
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: userName,
        password: password,
        databaseName: databaseName.trim().isNotEmpty ? databaseName.trim() : null,
        secure: false,
      );

      await conn.connect().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Failed to connect to MySQL on $host:$port (timed out)'),
      );

      // Execute query with timeout
      final result = await conn.execute(query).timeout(
        timeout,
        onTimeout: () => throw TimeoutException('Query execution timed out after ${timeout.inSeconds} seconds'),
      );

      stopwatch.stop();

      // Check if this was a SELECT / tabular result
      if (result.numOfColumns > 0) {
        final tableText = _formatResultSet(result);
        return ExecutionResult.success(
          tableText,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        final affected = result.affectedRows;
        final msg = 'Query OK, $affected row${affected == BigInt.one ? '' : 's'} affected.';
        return ExecutionResult.success(
          msg,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
    } on TimeoutException catch (e) {
      stopwatch.stop();
      return ExecutionResult.failure(
        e.message ?? 'Operation timed out',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on MySQLServerException catch (e) {
      stopwatch.stop();
      return ExecutionResult.failure(
        'SQL Error [${e.errorCode}]: ${e.message}',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult.failure(
        'Database Execution Failure: $e',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      if (conn != null) {
        try {
          await conn.close();
        } catch (_) {}
      }
    }
  }

  /// Executes a multi-statement setup script (e.g. DDL / sample data seeding).
  Future<ExecutionResult> executeSetupScript({
    required String setupScript,
    required String databaseName,
  }) async {
    if (setupScript.trim().isEmpty) {
      return ExecutionResult.success('No setup script required.');
    }

    final stopwatch = Stopwatch()..start();
    MySQLConnection? conn;

    try {
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: userName,
        password: password,
        databaseName: databaseName.trim().isNotEmpty ? databaseName.trim() : null,
        secure: false,
      );

      await conn.connect().timeout(const Duration(seconds: 5));

      // Split statements on semicolon while ignoring comments
      final statements = setupScript
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.startsWith('--'))
          .toList();

      int executedCount = 0;
      for (final stmt in statements) {
        await conn.execute(stmt);
        executedCount++;
      }

      stopwatch.stop();
      return ExecutionResult.success(
        'Successfully initialized schema ($executedCount statements executed).',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult.failure(
        'Failed to run database setup script: $e',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      if (conn != null) {
        try {
          await conn.close();
        } catch (_) {}
      }
    }
  }

  /// Formats a MySQL ResultSet into an ASCII grid table.
  String _formatResultSet(IResultSet result) {
    final headers = result.cols.map((c) => c.name).toList();
    if (headers.isEmpty) {
      return '(Empty Result Set)';
    }

    // Collect row string values
    final rowsData = <List<String>>[];
    for (final row in result.rows) {
      final rowVals = <String>[];
      for (int i = 0; i < headers.length; i++) {
        final val = row.colAt(i);
        rowVals.add(val ?? 'NULL');
      }
      rowsData.add(rowVals);
    }

    // Compute max width per column
    final colWidths = List<int>.generate(headers.length, (i) => headers[i].length);
    for (final row in rowsData) {
      for (int i = 0; i < headers.length; i++) {
        if (row[i].length > colWidths[i]) {
          colWidths[i] = row[i].length;
        }
      }
    }

    // Build the border line
    final border = '+${colWidths.map((w) => '-' * (w + 2)).join('+')}+';

    final sb = StringBuffer();
    sb.writeln(border);

    // Header row
    final headerRow = '| ${headers.asMap().entries.map((e) => e.value.padRight(colWidths[e.key])).join(' | ')} |';
    sb.writeln(headerRow);
    sb.writeln(border);

    // Data rows
    if (rowsData.isEmpty) {
      sb.writeln('| ${'(No records returned)'.padRight(colWidths.reduce((a, b) => a + b) + (headers.length - 1) * 3)} |');
    } else {
      for (final row in rowsData) {
        final r = '| ${row.asMap().entries.map((e) => e.value.padRight(colWidths[e.key])).join(' | ')} |';
        sb.writeln(r);
      }
    }

    sb.writeln(border);
    sb.writeln('${rowsData.length} row${rowsData.length == 1 ? '' : 's'} in set.');
    return sb.toString();
  }
}
