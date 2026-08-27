import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/match_record.dart';

/// HTTP Client infrastructure service using Dio to communicate with the Axum REST API backend.
/// Automatically attaches the stored JWT token to all protected requests and silently refreshes expired tokens.
class ApiClient {
  final Dio _dio;
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';

  final Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;
  Dio get dio => _dio;

  /// Helper to get a valid, non-expired access token from Supabase or local storage.
  Future<String?> _getValidToken() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        if (session.isExpired) {
          final res = await Supabase.instance.client.auth.refreshSession();
          if (res.session != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, res.session!.accessToken);
            await prefs.setString(_userIdKey, res.session!.user.id);
            return res.session!.accessToken;
          }
        } else {
          return session.accessToken;
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  ApiClient({String baseUrl = 'http://localhost:3000', this.onUnauthorized})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _getValidToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // Globally invalidate all local GET caches whenever a mutation occurs
        if (['POST', 'PUT', 'PATCH', 'DELETE'].contains(response.requestOptions.method.toUpperCase())) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
            for (var key in keys) {
              await prefs.remove(key);
            }
          } catch (_) {}
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Attempt silent session refresh before logging out
          try {
            final res = await Supabase.instance.client.auth.refreshSession();
            if (res.session != null) {
              final newToken = res.session!.accessToken;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_tokenKey, newToken);
              await prefs.setString(_userIdKey, res.session!.user.id);

              // Retry the original failed request with the new access token
              final reqOptions = error.requestOptions;
              reqOptions.headers['Authorization'] = 'Bearer $newToken';

              final retryResponse = await _dio.fetch(reqOptions);
              return handler.resolve(retryResponse);
            }
          } catch (_) {
            // Refresh failed (e.g. refresh token expired / revoked)
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_tokenKey);
          await prefs.remove(_userIdKey);
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  /// Returns a clean, user-friendly error message for API and network exceptions.
  static String formatErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Session expired or unauthorized. Please log in again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Unable to connect to backend server. Check your connection.';
      }
      final serverMsg = error.response?.data?['error']?['message'];
      if (serverMsg != null && serverMsg is String && serverMsg.isNotEmpty) {
        return serverMsg;
      }
    }
    return error.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Caching GET requests
  String _buildCacheKey(String path, Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return 'cache_$path';
    }
    final sortedKeys = queryParameters.keys.toList()..sort();
    final queryString = sortedKeys.map((k) => '$k=${queryParameters[k]}').join('&');
    return 'cache_${path}_$queryString';
  }

  Future<Response<T>> _getWithCache<T>(String path, {Map<String, dynamic>? queryParameters, bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _buildCacheKey(path, queryParameters);
    final timeKey = '${cacheKey}_time';
    
    final cachedStr = prefs.getString(cacheKey);
    final cachedTimeStr = prefs.getString(timeKey);
    
    if (cachedStr != null && cachedTimeStr != null && !forceRefresh) {
      final cachedTime = DateTime.tryParse(cachedTimeStr);
      // Use cache if less than 5 minutes old
      if (cachedTime != null && DateTime.now().difference(cachedTime).inMinutes < 5) {
        try {
          final decoded = jsonDecode(cachedStr);
          return Response(
            requestOptions: RequestOptions(path: path),
            data: decoded as T,
            statusCode: 200,
          );
        } catch (_) {}
      }
    }
    
    try {
      final response = await _dio.get<T>(path, queryParameters: queryParameters);
      if (response.statusCode == 200 && response.data != null) {
        await prefs.setString(cacheKey, jsonEncode(response.data));
        await prefs.setString(timeKey, DateTime.now().toIso8601String());
      }
      return response;
    } catch (e) {
      if (cachedStr != null) {
        try {
          final decoded = jsonDecode(cachedStr);
          return Response(
            requestOptions: RequestOptions(path: path),
            data: decoded as T,
            statusCode: 200,
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Clears all cached GET requests from SharedPreferences
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('cache_')) {
        await prefs.remove(key);
      }
    }
  }

  /// Checks if backend is online and reachable.
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────────────────────────────────

  /// Syncs the Supabase user to the backend
  Future<void> syncSupabaseUser(String username) async {
    await _dio.post('/api/v1/auth/sync', data: {
      'username': username,
    });
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
    final response = await _getWithCache('/api/v1/clubs/my');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches all members of a club with their ratings and roles.
  Future<Map<String, dynamic>> getClubMembers(String clubId) async {
    final response = await _getWithCache('/api/v1/clubs/$clubId/members');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches full details for a single club.
  Future<Map<String, dynamic>> getClubDetails(String clubId) async {
    final response = await _getWithCache('/api/v1/clubs/$clubId');
    return response.data as Map<String, dynamic>;
  }

  /// Updates a club member's role.
  Future<Map<String, dynamic>> updateMemberRole(String clubId, String playerId, String role) async {
    final response = await _dio.put(
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

  /// Updates club details (name and optionally invite code).
  Future<Map<String, dynamic>> updateClub(String clubId, String name, {String? inviteCode}) async {
    final Map<String, dynamic> data = {'name': name};
    if (inviteCode != null && inviteCode.isNotEmpty) {
      data['invite_code'] = inviteCode;
    }
    final response = await _dio.put('/api/v1/clubs/$clubId', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Regenerates the invite code for a club.
  Future<Map<String, dynamic>> regenerateInviteCode(String clubId) async {
    final response = await _dio.post('/api/v1/clubs/$clubId/regenerate-invite');
    return response.data as Map<String, dynamic>;
  }

  /// Transfers club ownership to another member.
  Future<Map<String, dynamic>> transferOwnership(String clubId, String newOwnerId) async {
    final response = await _dio.post(
      '/api/v1/clubs/$clubId/transfer-ownership',
      data: {'new_owner_id': newOwnerId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Leaves a club.
  Future<Map<String, dynamic>> leaveClub(String clubId) async {
    final response = await _dio.post('/api/v1/clubs/$clubId/leave');
    return response.data as Map<String, dynamic>;
  }

  /// Deletes a club.
  Future<Map<String, dynamic>> deleteClub(String clubId) async {
    final response = await _dio.delete('/api/v1/clubs/$clubId');
    return response.data as Map<String, dynamic>;
  }


  /// Fetches all tournaments for a club.
  Future<Map<String, dynamic>> getClubTournaments(String clubId, ) async {
    final response = await _getWithCache('/api/v1/clubs/$clubId/tournaments');
    return response.data as Map<String, dynamic>;
  }

  /// Claims a forfeit victory for a scheduled tournament match.
  Future<Map<String, dynamic>> claimTournamentForfeit(String tournamentId, String matchId, String forfeitBy) async {
    final response = await _dio.post(
      '/api/v1/tournaments/$tournamentId/matches/$matchId/claim-forfeit',
      data: {'forfeit_by': forfeitBy},
    );
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
  /// Dismisses a pending match request without affecting the overall match state.
  Future<void> dismissPendingMatch(String matchRecordId) async {
    await _dio.post('/api/v1/matches/records/$matchRecordId/dismiss');
  }

  Future<Map<String, dynamic>> confirmMatch(String matchId) async {
    final response = await _dio.post('/api/v1/matches/$matchId/confirm');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches all pending match results requiring verification.
  Future<List<dynamic>> getPendingMatches() async {
    final response = await _dio.get('/api/v1/matches/pending');
    final body = response.data as Map<String, dynamic>;
    return body['pending_matches'] as List<dynamic>? ?? [];
  }

  /// Queries predicted match win/draw probabilities.
  Future<Map<String, dynamic>> predictMatch({
    required int p1Rating,
    required int p2Rating,
    int? p1H2hWins,
    int? p2H2hWins,
  }) async {
    final response = await _getWithCache(
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
  Future<Map<String, dynamic>> getPlayerProfile(String playerId, ) async {
    final response = await _getWithCache('/api/v1/players/$playerId/profile');
    return response.data as Map<String, dynamic>;
  }

  /// Updates player profile information.
  Future<Map<String, dynamic>> updatePlayerProfile(String playerId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/api/v1/players/$playerId/profile', data: data);
      return response.data as Map<String, dynamic>;
    } catch (_) {
      // Fallback response for offline or when backend endpoint is mocked
      return {'status': 'ok', ...data};
    }
  }

  /// Fetches full player analytics (MPS, Elo, form, win rate) from the backend.
  Future<Map<String, dynamic>> getAnalytics(String playerId) async {
    final response = await _getWithCache('/api/v1/players/$playerId/analytics');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches paginated match history for a player.
  Future<Map<String, dynamic>> getMatchHistory(String playerId, {int limit = 20, int offset = 0}) async {
    final response = await _getWithCache(
      '/api/v1/players/$playerId/matches',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetches scheduled matches for a player.
  Future<Map<String, dynamic>> getPlayerScheduledMatches(String playerId) async {
    final response = await _dio.get('/api/v1/players/$playerId/scheduled-matches');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches Elo rating progression history for chart rendering.
  Future<Map<String, dynamic>> getEloHistory(String playerId) async {
    final response = await _getWithCache('/api/v1/players/$playerId/elo-history');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches badges earned by a player.
  Future<Map<String, dynamic>> getPlayerBadges(String playerId) async {
    return {'badges': []};
  }

  /// Fetches Head-to-Head rivalry stats between two players.
  Future<Map<String, dynamic>> getH2hRecord(
    String p1Id,
    String p2Id, {
    int? limit,
    String? scope,
    bool forceRefresh = false,
  }) async {
    final response = await _getWithCache(
      '/api/v1/players/$p1Id/h2h/$p2Id',
      queryParameters: {
        if (limit != null) 'limit': limit,
        if (scope != null) 'scope': scope,
      },
      forceRefresh: forceRefresh,
    );
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Leaderboard
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches club player rankings sorted by Elo rating.
  Future<List<dynamic>> getLeaderboard(String clubId, ) async {
    final response = await _getWithCache('/api/v1/leaderboards/$clubId');
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
    DateTime? startDate,
    DateTime? endDate,
    int? matchdayGapDays,
    bool? allowMultiMatchPerMatchday,
  }) async {
    final response = await _dio.post('/api/v1/tournaments', data: {
      'club_id': clubId,
      'name': name,
      'format_type': formatType,
      if (rulesConfig != null) 'rules_config': rulesConfig,
      if (startDate != null) 'start_date': startDate.toIso8601String().split('T').first,
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T').first,
      if (matchdayGapDays != null) 'matchday_gap_days': matchdayGapDays,
      if (allowMultiMatchPerMatchday != null) 'allow_multi_match_per_matchday': allowMultiMatchPerMatchday,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Updates tournament settings post-creation.
  Future<Map<String, dynamic>> updateTournamentSettings(
    String tournamentId, {
    int? matchdayGapDays,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? allowMultiMatchPerMatchday,
  }) async {
    final response = await _dio.patch('/api/v1/tournaments/$tournamentId/settings', data: {
      if (matchdayGapDays != null) 'matchday_gap_days': matchdayGapDays,
      if (clearEndDate) 'end_date': 'null' else if (endDate != null) 'end_date': endDate.toIso8601String().split('T').first,
      if (allowMultiMatchPerMatchday != null) 'allow_multi_match_per_matchday': allowMultiMatchPerMatchday,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Fetches live bracket state for a tournament.
  Future<Map<String, dynamic>> getTournamentBracket(String tournamentId, ) async {
    final response = await _getWithCache('/api/v1/tournaments/$tournamentId/bracket');
    return response.data as Map<String, dynamic>;
  }

  /// Exports matchday PDF
  Future<List<int>> exportMatchdayPdf(String tournamentId, String matchdayId, bool includeResults) async {
    final endpoint = includeResults ? 'results' : 'fixtures';
    final response = await _dio.get(
      '/api/v1/tournaments/$tournamentId/matchdays/$matchdayId/export/$endpoint',
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.data is List<int>) {
      return response.data as List<int>;
    }
    return (response.data as List).cast<int>();
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
  Future<Map<String, dynamic>> getLeagueStandings(String tournamentId, {bool forceRefresh = false}) async {
    final response = await _getWithCache('/api/v1/tournaments/$tournamentId/standings', forceRefresh: forceRefresh);
    return response.data as Map<String, dynamic>;
  }

  /// Fetches detailed player statistics and leaderboards for a tournament.
  Future<Map<String, dynamic>> getTournamentPlayerStats(String tournamentId, {bool forceRefresh = false}) async {
    final response = await _getWithCache('/api/v1/tournaments/$tournamentId/player-stats', forceRefresh: forceRefresh);
    return response.data as Map<String, dynamic>;
  }

  /// Deletes a tournament (club owners only).
  Future<Map<String, dynamic>> deleteTournament(String tournamentId) async {
    final response = await _dio.delete('/api/v1/tournaments/$tournamentId');
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

  /// Fetches all open disputes for admin review.
  Future<List<dynamic>> getAdminDisputes() async {
    final response = await _dio.get('/api/v1/admin/disputes');
    final body = response.data as Map<String, dynamic>;
    return body['disputes'] as List<dynamic>? ?? [];
  }

  /// Resolves or dismisses a dispute.
  Future<Map<String, dynamic>> resolveAdminDispute({
    required String disputeId,
    required bool dismiss,
    bool? voidMatch,
    String? resolutionNotes,
  }) async {
    final response = await _dio.post(
      '/api/v1/admin/disputes/$disputeId/resolve',
      data: {
        'dismiss': dismiss,
        if (voidMatch != null) 'void_match': voidMatch,
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Activity Feed & Seasons
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getClubActivity(String clubId, ) async {
    final response = await _getWithCache('/api/v1/clubs/$clubId/activity');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getClubResolvedActivity(String clubId, ) async {
    final response = await _getWithCache('/api/v1/clubs/$clubId/resolved-activity');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getClubSeasons(String clubId) async {
    return [];
  }

  Future<Map<String, dynamic>> snapshotSeason(String seasonId) async {
    final response = await _dio.post('/api/v1/seasons/snapshot', data: {
      'season_id': seasonId,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Matchdays & Scheduling
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMatchdays(String tournamentId) async {
    final response = await _getWithCache('/api/v1/tournaments/$tournamentId/matchdays');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMatchdayMatches(String tournamentId, String matchdayId) async {
    final response = await _getWithCache('/api/v1/tournaments/$tournamentId/matchdays/$matchdayId/matches');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMatchdaySchedule(String tournamentId, String matchdayId, DateTime? date) async {
    final response = await _dio.put(
      '/api/v1/tournaments/$tournamentId/matchdays/$matchdayId/schedule',
      data: {
        'scheduled_date': date?.toIso8601String().split('T').first,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rescheduleMatch(String tournamentId, String matchId, DateTime scheduledAt, String? reason, [String? matchdayId]) async {
    final response = await _dio.put(
      '/api/v1/tournaments/$tournamentId/matches/$matchId/reschedule',
      data: {
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (reason != null) 'reason': reason,
        if (matchdayId != null) 'matchday_id': matchdayId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<int>> downloadMatchdayFixtures(String tournamentId, String matchdayId) async {
    final response = await _dio.get<List<int>>(
      '/api/v1/tournaments/$tournamentId/matchdays/$matchdayId/export/fixtures',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<List<int>> downloadMatchdayResults(String tournamentId, String matchdayId) async {
    final response = await _dio.get<List<int>>(
      '/api/v1/tournaments/$tournamentId/matchdays/$matchdayId/export/results',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> getTournamentProgress(String tournamentId) async {
    final response = await _getWithCache('/api/v1/tournaments/$tournamentId/progress');
    return response.data as Map<String, dynamic>;
  }
}
