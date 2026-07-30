import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/match_record.dart';
import '../../infrastructure/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final matchSubmissionProvider =
    StateNotifierProvider<MatchSubmissionNotifier, AsyncValue<OcrSubmitResult?>>((ref) {
  return MatchSubmissionNotifier(ref.watch(apiClientProvider));
});

class MatchSubmissionNotifier extends StateNotifier<AsyncValue<OcrSubmitResult?>> {
  final ApiClient _apiClient;

  MatchSubmissionNotifier(this._apiClient) : super(const AsyncValue.data(null));

  Future<OcrSubmitResult?> submitMatchRecord(MatchRecord record) async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiClient.submitOcrMatch(record);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final matchPredictionProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final client = ref.watch(apiClientProvider);
  return client.predictMatch(
    p1Rating: params['p1Rating'] ?? 1000,
    p2Rating: params['p2Rating'] ?? 1000,
    p1H2hWins: params['p1H2hWins'],
    p2H2hWins: params['p2H2hWins'],
  );
});

final h2hRecordProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, String>>((ref, params) async {
  final client = ref.watch(apiClientProvider);
  return client.getH2hRecord(params['p1Id']!, params['p2Id']!);
});
