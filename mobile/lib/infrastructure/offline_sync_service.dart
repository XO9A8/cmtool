import 'dart:async';
import '../domain/models/match_record.dart';
import 'api_client.dart';

class OfflineSyncService {
  final ApiClient _apiClient;
  final List<MatchRecord> _pendingQueue = [];
  bool _isOnline = true;

  OfflineSyncService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  List<MatchRecord> get pendingQueue => List.unmodifiable(_pendingQueue);
  bool get isOnline => _isOnline;

  void enqueueOfflineMatch(MatchRecord record) {
    _pendingQueue.add(record);
  }

  void updateConnectivity(bool online) {
    _isOnline = online;
    if (_isOnline && _pendingQueue.isNotEmpty) {
      syncPendingUploads();
    }
  }

  Future<int> syncPendingUploads() async {
    if (!_isOnline || _pendingQueue.isEmpty) return 0;

    int syncedCount = 0;
    final toSync = List<MatchRecord>.from(_pendingQueue);

    for (final record in toSync) {
      try {
        await _apiClient.submitOcrMatch(record);
        _pendingQueue.remove(record);
        syncedCount++;
      } catch (e) {
        // Leave in queue to retry on next sync cycle
      }
    }

    return syncedCount;
  }
}
