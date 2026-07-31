import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../infrastructure/api_client.dart';
import '../domain/models/match_record.dart';
import '../presentation/providers/match_provider.dart';


/// Manages offline-first match submission using a local SQLite queue.
///
/// When the device is offline, match records are stored locally.
/// When connectivity is restored, this service drains the queue and
/// calls the API to sync pending matches.
class OfflineSyncService {
  static const _dbName = 'cmtool_offline.db';
  static const _tableName = 'pending_matches';

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = '${await getDatabasesPath()}/$_dbName';
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT NOT NULL,
            opponent_id TEXT NOT NULL,
            match_type TEXT NOT NULL,
            goals_for INTEGER NOT NULL,
            goals_against INTEGER NOT NULL,
            possession REAL NOT NULL,
            passes_completed INTEGER NOT NULL,
            passes_attempted INTEGER NOT NULL,
            shots_on_target INTEGER NOT NULL,
            shots_total INTEGER NOT NULL,
            interceptions INTEGER NOT NULL,
            screenshot_hash TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// Enqueues a match record to be synced when connectivity is available.
  Future<void> enqueue(MatchRecord record) async {
    final db = await _database;
    await db.insert(_tableName, {
      'player_id': record.playerId,
      'opponent_id': record.opponentId,
      'match_type': record.matchType,
      'goals_for': record.goalsFor,
      'goals_against': record.goalsAgainst,
      'possession': record.possession,
      'passes_completed': record.passesCompleted,
      'passes_attempted': record.passesAttempted,
      'shots_on_target': record.shotsOnTarget,
      'shots_total': record.shotsTotal,
      'interceptions': record.interceptions,
      'screenshot_hash': record.screenshotHash,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Returns the number of matches pending sync.
  Future<int> get pendingCount async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Attempts to sync all pending matches. Removes successfully synced records.
  Future<SyncResult> syncPending(ApiClient client) async {
    final db = await _database;
    final rows = await db.query(_tableName, orderBy: 'created_at ASC');

    int synced = 0;
    int failed = 0;

    for (final row in rows) {
      try {
        final record = MatchRecord(
          playerId:         row['player_id'] as String,
          opponentId:       row['opponent_id'] as String,
          matchType:        row['match_type'] as String,
          goalsFor:         row['goals_for'] as int,
          goalsAgainst:     row['goals_against'] as int,
          possession:       row['possession'] as double,
          passesCompleted:  row['passes_completed'] as int,
          passesAttempted:  row['passes_attempted'] as int,
          shotsOnTarget:    row['shots_on_target'] as int,
          shotsTotal:       row['shots_total'] as int,
          interceptions:    row['interceptions'] as int,
          screenshotHash:   row['screenshot_hash'] as String,
        );

        await client.submitOcrMatch(record);
        await db.delete(_tableName, where: 'id = ?', whereArgs: [row['id']]);
        synced++;
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }

  /// Tries to submit a match immediately. Falls back to local queue if offline.
  /// Returns true if submitted live, false if queued.
  Future<bool> submitOrQueue({
    required ApiClient client,
    required MatchRecord record,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);

    if (isOnline) {
      try {
        await client.submitOcrMatch(record);
        return true;
      } catch (_) {
        // Fall through to queue
      }
    }

    await enqueue(record);
    return false;
  }

  /// Starts listening for connectivity changes and syncs when online.
  void startAutoSync(WidgetRef ref) {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (!result.contains(ConnectivityResult.none)) {
        final count = await pendingCount;
        if (count > 0) {
          final client = ref.read(apiClientProvider);
          await syncPending(client);
        }
      }
    });
  }
}

/// Summary of a sync operation.
class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({required this.synced, required this.failed});
}

/// Riverpod provider for the offline sync service singleton.
final offlineSyncProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService();
});
