import 'dart:convert';

/// Represents the status of the local execution environment (Python and MySQL).
class EnvironmentStatus {
  final bool hasPython;
  final bool hasMySQL;
  final List<String> databases;
  final String? pythonVersion;
  final String? mysqlDetails;

  const EnvironmentStatus({
    required this.hasPython,
    required this.hasMySQL,
    required this.databases,
    this.pythonVersion,
    this.mysqlDetails,
  });

  factory EnvironmentStatus.initial() {
    return const EnvironmentStatus(
      hasPython: false,
      hasMySQL: false,
      databases: [],
      pythonVersion: null,
      mysqlDetails: null,
    );
  }

  EnvironmentStatus copyWith({
    bool? hasPython,
    bool? hasMySQL,
    List<String>? databases,
    String? pythonVersion,
    String? mysqlDetails,
  }) {
    return EnvironmentStatus(
      hasPython: hasPython ?? this.hasPython,
      hasMySQL: hasMySQL ?? this.hasMySQL,
      databases: databases ?? this.databases,
      pythonVersion: pythonVersion ?? this.pythonVersion,
      mysqlDetails: mysqlDetails ?? this.mysqlDetails,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasPython': hasPython,
      'hasMySQL': hasMySQL,
      'databases': databases,
      'pythonVersion': pythonVersion,
      'mysqlDetails': mysqlDetails,
    };
  }

  factory EnvironmentStatus.fromMap(Map<String, dynamic> map) {
    return EnvironmentStatus(
      hasPython: map['hasPython'] as bool? ?? false,
      hasMySQL: map['hasMySQL'] as bool? ?? false,
      databases: List<String>.from(map['databases'] as List? ?? []),
      pythonVersion: map['pythonVersion'] as String?,
      mysqlDetails: map['mysqlDetails'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory EnvironmentStatus.fromJson(String source) =>
      EnvironmentStatus.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'EnvironmentStatus(hasPython: $hasPython, hasMySQL: $hasMySQL, databases: $databases, pythonVersion: $pythonVersion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnvironmentStatus &&
        other.hasPython == hasPython &&
        other.hasMySQL == hasMySQL &&
        other.databases.length == databases.length &&
        other.pythonVersion == pythonVersion &&
        other.mysqlDetails == mysqlDetails;
  }

  @override
  int get hashCode {
    return Object.hash(
      hasPython,
      hasMySQL,
      databases.length,
      pythonVersion,
      mysqlDetails,
    );
  }
}
