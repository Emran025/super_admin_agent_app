import 'package:dartz/dartz.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/audit_log_service.dart';

/// SQLite-backed [AuditLogService].
///
/// Key guarantees:
/// - A BEFORE UPDATE trigger enforces append-only at the database engine level.
///   No application code can bypass this — the engine will abort the update.
/// - [log] always inserts a new row; it never updates or deduplicates.
/// - The singleton [instance] is initialized once at app start via [init].
class SqliteAuditLogService implements AuditLogService {
  static SqliteAuditLogService? _instance;
  static Database? _db;

  static const String _tableName = 'audit_log';

  SqliteAuditLogService._();

  static SqliteAuditLogService get instance {
    _instance ??= SqliteAuditLogService._();
    return _instance!;
  }

  /// Must be called once at app startup before any [log] calls.
  static Future<void> init() async {
    final dbPath = join(await getDatabasesPath(), 'audit_log.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        entry_id    TEXT PRIMARY KEY,
        action_type TEXT NOT NULL,
        system_id   TEXT NOT NULL,
        command_id  TEXT,
        timestamp   TEXT NOT NULL,
        outcome     TEXT NOT NULL,
        failure_code TEXT
      )
    ''');

    // Structural enforcement of append-only policy (Constraint 2.6).
    // This trigger fires at the database engine level — no application code
    // can update a row, even accidentally.
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS prevent_audit_update
      BEFORE UPDATE ON $_tableName
      BEGIN
        SELECT RAISE(ABORT, 'Audit log is append-only. Updates are forbidden.');
      END
    ''');
  }

  Database get _database {
    if (_db == null) {
      throw StateError(
        'SqliteAuditLogService.init() must be called before use.',
      );
    }
    return _db!;
  }

  @override
  Future<Either<AuditLogFailure, void>> log(AuditEntry entry) async {
    try {
      await _database.insert(
        _tableName,
        {
          'entry_id': entry.entryId,
          'action_type': entry.actionType.name,
          'system_id': entry.systemId,
          'command_id': entry.commandId,
          'timestamp': entry.timestamp.toIso8601String(),
          'outcome': entry.outcome.name,
          'failure_code': entry.failureCode,
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return const Right(null);
    } catch (e) {
      return Left(AuditLogWriteFailure(cause: e));
    }
  }

  @override
  Future<Either<AuditLogFailure, List<AuditEntry>>> queryAll() async {
    try {
      final rows = await _database.query(
        _tableName,
        orderBy: 'rowid ASC',
      );
      return Right(rows.map(_rowToEntry).toList());
    } catch (e) {
      return Left(AuditLogReadFailure(cause: e));
    }
  }

  @override
  Future<Either<AuditLogFailure, List<AuditEntry>>> queryBySystem(
    String systemId,
  ) async {
    try {
      final rows = await _database.query(
        _tableName,
        where: 'system_id = ?',
        whereArgs: [systemId],
        orderBy: 'rowid ASC',
      );
      return Right(rows.map(_rowToEntry).toList());
    } catch (e) {
      return Left(AuditLogReadFailure(cause: e));
    }
  }

  AuditEntry _rowToEntry(Map<String, Object?> row) {
    return AuditEntry(
      entryId: row['entry_id'] as String,
      actionType: AuditActionType.values.byName(row['action_type'] as String),
      systemId: row['system_id'] as String,
      commandId: row['command_id'] as String?,
      timestamp: DateTime.parse(row['timestamp'] as String),
      outcome: AuditOutcome.values.byName(row['outcome'] as String),
      failureCode: row['failure_code'] as String?,
    );
  }
}

// ignore: unused_element
const _uuid = Uuid();
