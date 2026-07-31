import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/match_record.dart';

/// HTTP Client infrastructure service using Dio to communicate with the Axum REST API backend.
/// Automatically attaches the stored JWT token to all protected requests.
class ApiClient {
  final Dio _dio;
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';

  ApiClient({String baseUrl = 'http://localhost:3000'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────────────────────────────────

  /// Registers a new user and stores the returned JWT token + user_id.
  Future<Map<String, dynamic>> registerUser(String username, String password) async {
    final response = await _dio.post('/api/v1/auth/register', data: {
      'username': username,
      'password': password,
    });
    await _persistSession(response.data);
    return response.data as Map<String, dynamic>;
  }

  /// Logs in a user and stores the returned JWT token + user_id.
  Future<Map<String, dynamic>> loginUser(String username, String password) async {
    final response = await _dio.post('/api/v1/auth/login', data: {
      'username': username,
      'password': password,
    });
    await _persistSession(response.data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> _persistSession(dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['token'] != null) {
      await prefs.setString(_tokenKey, data['token'] as String);
    }
    if (data['user_id'] != null) {
      await prefs.setString(_userIdKey, data['user_id'].toString());
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  Future<bool> get isLoggedIn async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  Future<String?> get storedUserId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Clubs
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new club. Returns the created club details.
  Future<Map<String, dynamic>> createClub(String name, String inviteCode) async {
    final response = await _dio.post('/api/v1/clubs', data: {
      'name': name,
      'invite_code': inviteCode,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Joins a club using an invite code.
  Future<Map<String, dynamic>> joinClub(String inviteCode) async {
    final response = await _dio.post(
      '/api/v1/clubs/join',
      data: {'invite_code': inviteCode},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetches all clubs the current player belongs to.
  Future<Map<String, dynamic>> getMyClubs() async {
    final response = await _dio.get('/api/v1/clubs/my');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches all members of a club with their ratings and roles.
  Future<Map<String, dynamic>> getClubMembers(String clubId) async {
    final response = await _dio.get('/api/v1/clubs/$clubId/members');
    return response.data as Map<String, dynamic>;
  }

  /// Updates a club member's role.
  Future<Map<String, dynamic>> updateMemberRole(String clubId, String playerId, String role) async {
    final response = await _dio.post(
      '/api/v1/clubs/$clubId/members/$playerId/role',
      data: {'role': role},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Removes a member from a club.
  Future<Map<String, dynamic>> removeMember(String clubId, String playerId) async {
    final response = await _dio.delete('/api/v1/clubs/$clubId/members/$playerId');
    return response.data as Map<String, dynamic>;
  }

  /// Updates club details (name and invite code).
  Future<Map<String, dynamic>> updateClub(String clubId, String name, String inviteCode) async {
    final response = await _dio.put('/api/v1/clubs/$clubId', data: {
      'name': name,
      'invite_code': inviteCode,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Fetches all tournaments for a club.
  Future<Map<String, dynamic>> getClubTournaments(String clubId) async {
    final response = await _dio.get('/api/v1/clubs/$clubId/tournaments');
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Match Operations
  // ─────────────────────────────────────────────────────────────────────────

  /// Submits post-match OCR statistical payload to the backend.
  Future<OcrSubmitResult> submitOcrMatch(MatchRecord record) async {
    final response = await _dio.post(
      '/api/v1/matches/ocr-submit',
      data: record.toJson(),
    );
    return OcrSubmitResult.fromJson(response.data);
  }

  /// Confirms a pending match result as the opponent.
  Future<Map<String, dynamic>> confirmMatch(String matchId) async {
    final response = await _dio.post('/api/v1/matches/$matchId/confirm');
    return response.data as Map<String, dynamic>;
  }

  /// Queries predicted match win/draw probabilities.
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

  // ─────────────────────────────────────────────────────────────────────────
  // Player Profile & Analytics
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches full player profile (analytics, clubs, badges combined).
  Future<Map<String, dynamic>> getPlayerProfile(String playerId) async {
    final response = await _dio.get('/api/v1/players/$playerId/profile');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches full player analytics (MPS, Elo, form, win rate) from the backend.
  Future<Map<String, dynamic>> getAnalytics(String playerId) async {
    final response = await _dio.get('/api/v1/players/$playerId/analytics');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches paginated match history for a player.
  Future<Map<String, dynamic>> getMatchHistory(String playerId, {int limit = 20, int offset = 0}) async {
    final response = await _dio.get(
      '/api/v1/players/$playerId/matches',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetches Elo rating progression history for chart rendering.
  Future<Map<String, dynamic>> getEloHistory(String playerId) async {
    final response = await _dio.get('/api/v1/players/$playerId/elo-history');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches badges earned by a player.
  Future<Map<String, dynamic>> getPlayerBadges(String playerId) async {
    final response = await _dio.get('/api/v1/players/$playerId/badges');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches Head-to-Head rivalry stats between two players.
  Future<Map<String, dynamic>> getH2hRecord(String p1Id, String p2Id) async {
    final response = await _dio.get('/api/v1/players/$p1Id/h2h/$p2Id');
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Leaderboard
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches club player rankings sorted by Elo rating.
  Future<List<dynamic>> getLeaderboard(String clubId) async {
    final response = await _dio.get('/api/v1/leaderboards/$clubId');
    return response.data as List<dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tournaments
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a tournament and persists it to the database.
  Future<Map<String, dynamic>> createTournament({
    required String clubId,
    required String name,
    required String formatType,
    Map<String, dynamic>? rulesConfig,
  }) async {
    final response = await _dio.post('/api/v1/tournaments', data: {
      'club_id': clubId,
      'name': name,
      'format_type': formatType,
      if (rulesConfig != null) 'rules_config': rulesConfig,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Fetches live bracket state for a tournament.
  Future<Map<String, dynamic>> getTournamentBracket(String tournamentId) async {
    final response = await _dio.get('/api/v1/tournaments/$tournamentId/bracket');
    return response.data as Map<String, dynamic>;
  }

  /// Starts a tournament with given players - generates fixtures and sets status to active.
  Future<Map<String, dynamic>> startTournament(String tournamentId, List<Map<String, dynamic>> players) async {
    final response = await _dio.post(
      '/api/v1/tournaments/$tournamentId/start',
      data: {'players': players},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Updates a tournament's status (draft, active, completed).
  Future<Map<String, dynamic>> updateTournamentStatus(String tournamentId, String status) async {
    final response = await _dio.post(
      '/api/v1/tournaments/$tournamentId/status',
      data: {'status': status},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetches live league standings for a tournament.
  Future<Map<String, dynamic>> getLeagueStandings(String tournamentId) async {
    final response = await _dio.get('/api/v1/tournaments/$tournamentId/standings');
    return response.data as Map<String, dynamic>;
  }

  /// Submits squad screenshot for pre-match strength verification.
  Future<Map<String, dynamic>> submitSquadCheck({
    required String tMatchId,
    required int teamStrength,
    required String screenshotUrl,
    int maxStrength = 2900,
  }) async {
    final response = await _dio.post(
      '/api/v1/tournaments/$tMatchId/squad-check',
      data: {
        'team_strength': teamStrength,
        'screenshot_url': screenshotUrl,
        'max_strength': maxStrength,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Disputes
  // ─────────────────────────────────────────────────────────────────────────

  /// Submits a match result dispute for admin review.
  Future<Map<String, dynamic>> submitDispute({
    required String matchRecordId,
    required String reason,
  }) async {
    final response = await _dio.post('/api/v1/disputes', data: {
      'match_record_id': matchRecordId,
      'reason': reason,
    });
    return response.data as Map<String, dynamic>;
  }
}
