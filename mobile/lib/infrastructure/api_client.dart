import 'package:dio/dio.dart';
import '../domain/models/match_record.dart';

class ApiClient {
  final Dio _dio;
  static const String baseUrl = 'http://localhost:3000';

  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              headers: {'Content-Type': 'application/json'},
            ));

  Future<OcrSubmitResult> submitOcrMatch(MatchRecord record) async {
    final response = await _dio.post(
      '/api/v1/matches/ocr-submit',
      data: record.toJson(),
    );
    return OcrSubmitResult.fromJson(response.data);
  }

  Future<Map<String, dynamic>> predictMatch({
    required int p1Rating,
    required int p2Rating,
    int? p1H2hWins,
    int? p2H2hWins,
  }) async {
    final response = await _dio.get(
      '/api/v1/matches/predict',
      queryParameters: {
        'p1_rating': p1Rating,
        'p2_rating': p2Rating,
        'p1_h2h_wins': p1H2hWins ?? 0,
        'p2_h2h_wins': p2H2hWins ?? 0,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getH2hRecord(String p1Id, String p2Id) async {
    final response = await _dio.get('/api/v1/players/$p1Id/h2h/$p2Id');
    return response.data;
  }
}
