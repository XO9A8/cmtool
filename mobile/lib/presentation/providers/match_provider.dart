import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../infrastructure/api_client.dart';
import '../../domain/models/match_record.dart';


import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// ApiClient Singleton Provider
// ─────────────────────────────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://127.0.0.1:3000';
  return ApiClient(baseUrl: baseUrl);
});

// ─────────────────────────────────────────────────────────────────────────────
// Auth State
// ─────────────────────────────────────────────────────────────────────────────

/// Auth state containing the stored user ID (null = not logged in).
final authStateProvider = StateNotifierProvider<AuthNotifier, String?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier() : super(null) {
    _loadStoredSession();
  }

  Future<void> _loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    state = userId;
  }

  Future<void> login(ApiClient client, String username, String password) async {
    final res = await client.loginUser(username, password);
    state = res['user_id']?.toString();
  }

  Future<void> register(ApiClient client, String username, String password) async {
    final res = await client.registerUser(username, password);
    state = res['user_id']?.toString();
  }

  Future<void> logout(ApiClient client) async {
    await client.logout();
    state = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player Analytics Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches analytics for the given player ID from the backend.
final analyticsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, playerId) async {
  final client = ref.watch(apiClientProvider);
  return client.getAnalytics(playerId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Player Profile Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches full player profile including analytics, clubs, and badges.
final playerProfileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, playerId) async {
  final client = ref.watch(apiClientProvider);
  return client.getPlayerProfile(playerId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Match History Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches paginated match history for a player.
final matchHistoryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, playerId) async {
  final client = ref.watch(apiClientProvider);
  return client.getMatchHistory(playerId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Elo History Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches Elo rating progression for chart rendering.
final eloHistoryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, playerId) async {
  final client = ref.watch(apiClientProvider);
  return client.getEloHistory(playerId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Player Badges Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches badges earned by a player.
final playerBadgesProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, playerId) async {
  final client = ref.watch(apiClientProvider);
  return client.getPlayerBadges(playerId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the club leaderboard for the given club ID.
final leaderboardProvider = FutureProvider.family<List<dynamic>, String>((ref, clubId) async {
  final client = ref.watch(apiClientProvider);
  return client.getLeaderboard(clubId);
});

// ─────────────────────────────────────────────────────────────────────────────
// My Clubs Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all clubs the current user belongs to.
final myClubsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getMyClubs();
});

// ─────────────────────────────────────────────────────────────────────────────
// Club Members Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all members of a club with their ratings and roles.
final clubMembersProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, clubId) async {
  final client = ref.watch(apiClientProvider);
  return client.getClubMembers(clubId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Club Tournaments Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all tournaments for a club.
final clubTournamentsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, clubId) async {
  final client = ref.watch(apiClientProvider);
  return client.getClubTournaments(clubId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Match Prediction Provider
// ─────────────────────────────────────────────────────────────────────────────

class PredictParams {
  final int p1Rating;
  final int p2Rating;
  final int p1H2hWins;
  final int p2H2hWins;
  const PredictParams({
    required this.p1Rating,
    required this.p2Rating,
    this.p1H2hWins = 0,
    this.p2H2hWins = 0,
  });
}

final matchPredictionProvider = FutureProvider.family<Map<String, dynamic>, PredictParams>((ref, params) async {
  final client = ref.watch(apiClientProvider);
  return client.predictMatch(
    p1Rating: params.p1Rating,
    p2Rating: params.p2Rating,
    p1H2hWins: params.p1H2hWins,
    p2H2hWins: params.p2H2hWins,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// H2H Provider
// ─────────────────────────────────────────────────────────────────────────────

class H2hParams {
  final String p1Id;
  final String p2Id;
  const H2hParams({required this.p1Id, required this.p2Id});
}

final h2hProvider = FutureProvider.family<Map<String, dynamic>, H2hParams>((ref, params) async {
  final client = ref.watch(apiClientProvider);
  return client.getH2hRecord(params.p1Id, params.p2Id);
});

// ─────────────────────────────────────────────────────────────────────────────
// OCR Submit Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// State for OCR match submission: null = idle, AsyncValue.loading = submitting, data = result.
final ocrSubmitProvider = StateNotifierProvider<OcrSubmitNotifier, AsyncValue<OcrSubmitResult?>>((ref) {
  return OcrSubmitNotifier(ref.watch(apiClientProvider));
});

class OcrSubmitNotifier extends StateNotifier<AsyncValue<OcrSubmitResult?>> {
  final ApiClient _client;
  OcrSubmitNotifier(this._client) : super(const AsyncValue.data(null));

  Future<void> submit(MatchRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _client.submitOcrMatch(record));
  }

  void reset() => state = const AsyncValue.data(null);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tournament Bracket Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches live tournament bracket for the given tournament ID.
final tournamentBracketProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, tournamentId) async {
  final client = ref.watch(apiClientProvider);
  return client.getTournamentBracket(tournamentId);
});

// ─────────────────────────────────────────────────────────────────────────────
// League Standings Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches live league standings for a tournament.
final leagueStandingsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, tournamentId) async {
  final client = ref.watch(apiClientProvider);
  return client.getLeagueStandings(tournamentId);
});
