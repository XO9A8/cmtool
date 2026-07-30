import 'package:dio/dio.dart';
import '../domain/models/match_record.dart';

/// HTTP Client infrastructure service using Dio to communicate with the Axum REST API backend.
class ApiClient {
  final Dio _dio;

  /// Initializes ApiClient pointing to backend base URL (defaults to http://localhost:3000).
  ApiClient({String baseUrl = 'http://localhost:3000'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));

  /// Submits post-match OCR statistical payload to `/api/v1/matches/ocr-submit`.
  Future<OcrSubmitResult> submitOcrMatch(MatchRecord record) async {
    final response = await _dio.post(
      '/api/v1/matches/ocr-submit',
      data: record.toJson(),
    );
    return OcrSubmitResult.fromJson(response.data);
  }

  /// Queries predicted match win/draw probabilities from `/api/v1/matches/predict`.
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
        if (p1H2hWins != null) 'p1_h2h_wins': p1H2hWins,
        if (p2H2hWins != null) 'p2_h2h_wins': p2H2hWins,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetches Head-to-Head rivalry stats from `/api/v1/players/:id/h2h/:opponent_id`.
  Future<Map<String, dynamic>> getH2hRecord(String p1Id, String p2Id) async {
    final response = await _dio.get('/api/v1/players/$p1Id/h2h/$p2Id');
    return response.data as Map<String, dynamic>;
  }

  /// Registers user account with `/api/v1/auth/register`.
  Future<Map<String, dynamic>> registerUser(String username, String password) async {
    final response = await _dio.post(
      '/api/v1/auth/register',
      data: {
        'username': username,
        'password': password,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Authenticates user credentials with `/api/v1/auth/login`.
  Future<Map<String, dynamic>> loginUser(String username, String password) async {
    final response = await _dio.post(
      '/api/v1/auth/login',
      data: {
        'username': username,
        'password': password,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
