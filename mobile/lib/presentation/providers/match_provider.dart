import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/api_client.dart';
import '../../domain/models/match_record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApiClient Singleton Provider
// ─────────────────────────────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) {
  const envUrl = String.fromEnvironment('BACKEND_URL');
  final baseUrl = envUrl.isNotEmpty ? envUrl : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://127.0.0.1:3000');
  return ApiClient(
    baseUrl: baseUrl,
    onUnauthorized: () {
      ref.read(authStateProvider.notifier).forceLogout();
    },
  );
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
    _initSupabaseAuth();
  }

  void _initSupabaseAuth() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final prefs = await SharedPreferences.getInstance();
      if (session != null) {
        state = session.user.id;
        await prefs.setString('jwt_token', session.accessToken);
        await prefs.setString('user_id', session.user.id);
      } else {
        state = null;
        await prefs.remove('jwt_token');
        await prefs.remove('user_id');
      }
    });
  }

  Future<void> login(ApiClient client, String username, String password) async {
    final email = username.contains('@') ? username : '$username@example.com';
    await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    await client.syncSupabaseUser(username);
  }

  Future<void> register(ApiClient client, String username, String password) async {
    final email = username.contains('@') ? username : '$username@example.com';
    await Supabase.instance.client.auth.signUp(email: email, password: password);
    await client.syncSupabaseUser(username);
  }

  Future<void> logout(ApiClient client) async {
    await Supabase.instance.client.auth.signOut();
  }

  void forceLogout() {
    state = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Preferences Provider
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePreferences {
  final String displayName;
  final String playStyle;
  final bool isPublic;
  final String contactEmail;
  final String preferredFoot;
  final String gameId;
  final String jerseyNumber;
  final String systemDevice;
  final String facebook;
  final String facebookLink;
  final String phoneLine;
  final String district;
  final String dateOfBirth;
  final String bio;
  final String? avatarGraphic;

  const ProfilePreferences({
    this.displayName = 'Player',
    this.playStyle = 'Possession Game',
    this.isPublic = true,
    this.contactEmail = '',
    this.preferredFoot = 'Right',
    this.gameId = '',
    this.jerseyNumber = '',
    this.systemDevice = 'PlayStation 5',
    this.facebook = '',
    this.facebookLink = '',
    this.phoneLine = '',
    this.district = '',
    this.dateOfBirth = '',
    this.bio = '',
    this.avatarGraphic = 'striker',
  });

  String get safeDisplayName => (displayName as dynamic)?.toString() ?? 'Player';
  String get safePlayStyle => (playStyle as dynamic)?.toString() ?? 'Possession Game';
  String get safeContactEmail => (contactEmail as dynamic)?.toString() ?? '';
  String get safePreferredFoot => (preferredFoot as dynamic)?.toString() ?? 'Right';
  String get safeGameId => (gameId as dynamic)?.toString() ?? '';
  String get safeJerseyNumber => (jerseyNumber as dynamic)?.toString() ?? '';
  String get safeSystemDevice => (systemDevice as dynamic)?.toString() ?? 'PlayStation 5';
  String get safeFacebookLink => (facebookLink as dynamic)?.toString() ?? '';
  String get safePhoneLine => (phoneLine as dynamic)?.toString() ?? '';
  String get safeDistrict => (district as dynamic)?.toString() ?? '';
  String get safeDateOfBirth => (dateOfBirth as dynamic)?.toString() ?? '';
  String get safeBio => (bio as dynamic)?.toString() ?? '';
  String get safeAvatarGraphic => avatarGraphic ?? 'striker';

  ProfilePreferences copyWith({
    String? displayName,
    String? playStyle,
    bool? isPublic,
    String? contactEmail,
    String? preferredFoot,
    String? gameId,
    String? jerseyNumber,
    String? systemDevice,
    String? facebook,
    String? facebookLink,
    String? phoneLine,
    String? district,
    String? dateOfBirth,
    String? bio,
    String? avatarGraphic,
  }) {
    return ProfilePreferences(
      displayName: displayName ?? this.displayName,
      playStyle: playStyle ?? this.playStyle,
      isPublic: isPublic ?? this.isPublic,
      contactEmail: contactEmail ?? this.contactEmail,
      preferredFoot: preferredFoot ?? this.preferredFoot,
      gameId: gameId ?? this.gameId,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      systemDevice: systemDevice ?? this.systemDevice,
      facebook: facebook ?? this.facebook,
      facebookLink: facebookLink ?? this.facebookLink,
      phoneLine: phoneLine ?? this.phoneLine,
      district: district ?? this.district,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bio: bio ?? this.bio,
      avatarGraphic: avatarGraphic ?? this.avatarGraphic,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'play_style': playStyle,
        'is_public': isPublic,
        'contact_email': contactEmail,
        'preferred_foot': preferredFoot,
        'game_id': gameId,
        'jersey_number': jerseyNumber,
        'system_device': systemDevice,
        'facebook': facebook,
        'facebook_link': facebookLink,
        'phone_line': phoneLine,
        'district': district,
        'date_of_birth': dateOfBirth,
        'bio': bio,
        'avatar_graphic': avatarGraphic,
      };

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) {
    return ProfilePreferences(
      displayName: json['display_name']?.toString() ?? 'Player',
      playStyle: json['play_style']?.toString() ?? 'Possession Game',
      isPublic: json['is_public'] is bool ? json['is_public'] as bool : true,
      contactEmail: json['contact_email']?.toString() ?? '',
      preferredFoot: json['preferred_foot']?.toString() ?? 'Right',
      gameId: json['game_id']?.toString() ?? '',
      jerseyNumber: json['jersey_number']?.toString() ?? '',
      systemDevice: json['system_device']?.toString() ?? 'PlayStation 5',
      facebook: json['facebook']?.toString() ?? '',
      facebookLink: json['facebook_link']?.toString() ?? '',
      phoneLine: json['phone_line']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      dateOfBirth: json['date_of_birth']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      avatarGraphic: json['avatar_graphic']?.toString() ?? 'striker',
    );
  }
}

final profilePreferencesProvider = StateNotifierProvider<ProfilePreferencesNotifier, ProfilePreferences>((ref) {
  return ProfilePreferencesNotifier();
});

class ProfilePreferencesNotifier extends StateNotifier<ProfilePreferences> {
  static const _storageKey = 'profile_preferences';

  ProfilePreferencesNotifier() : super(const ProfilePreferences()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = ProfilePreferences.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Ignore malformed stored preferences and keep the defaults.
    }
  }

  Future<void> update({
    String? displayName,
    String? playStyle,
    bool? isPublic,
    String? contactEmail,
    String? preferredFoot,
    String? gameId,
    String? jerseyNumber,
    String? systemDevice,
    String? facebook,
    String? facebookLink,
    String? phoneLine,
    String? district,
    String? dateOfBirth,
    String? bio,
    String? avatarGraphic,
  }) async {
    final next = state.copyWith(
      displayName: displayName,
      playStyle: playStyle,
      isPublic: isPublic,
      contactEmail: contactEmail,
      preferredFoot: preferredFoot,
      gameId: gameId,
      jerseyNumber: jerseyNumber,
      systemDevice: systemDevice,
      facebook: facebook,
      facebookLink: facebookLink,
      phoneLine: phoneLine,
      district: district,
      dateOfBirth: dateOfBirth,
      bio: bio,
      avatarGraphic: avatarGraphic,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(next.toJson()));
    state = next;
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

final playerScheduledMatchesProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, playerId) async {
  final client = ref.watch(apiClientProvider);
  return client.getPlayerScheduledMatches(playerId);
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PredictParams &&
          runtimeType == other.runtimeType &&
          p1Rating == other.p1Rating &&
          p2Rating == other.p2Rating &&
          p1H2hWins == other.p1H2hWins &&
          p2H2hWins == other.p2H2hWins;

  @override
  int get hashCode =>
      p1Rating.hashCode ^ p2Rating.hashCode ^ p1H2hWins.hashCode ^ p2H2hWins.hashCode;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is H2hParams &&
          runtimeType == other.runtimeType &&
          p1Id == other.p1Id &&
          p2Id == other.p2Id;

  @override
  int get hashCode => p1Id.hashCode ^ p2Id.hashCode;
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

// ─────────────────────────────────────────────────────────────────────────────
// Club Activity Feed Provider
// ─────────────────────────────────────────────────────────────────────────────

final clubActivityProvider = FutureProvider.family<List<dynamic>, String>((ref, clubId) async {
  final client = ref.watch(apiClientProvider);
  return await client.getClubActivity(clubId);
});

final clubResolvedActivityProvider = FutureProvider.family<List<dynamic>, String>((ref, clubId) async {
  final client = ref.watch(apiClientProvider);
  return await client.getClubResolvedActivity(clubId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Club Seasons Provider
// ─────────────────────────────────────────────────────────────────────────────

final clubSeasonsProvider = FutureProvider.family<List<dynamic>, String>((ref, clubId) async {
  final client = ref.watch(apiClientProvider);
  return client.getClubSeasons(clubId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Admin Disputes Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all open match disputes for admin review.
final adminDisputesProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getAdminDisputes();
});

// ─────────────────────────────────────────────────────────────────────────────
// Pending Matches Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all pending match results requiring verification by the user or official.
final pendingMatchesProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getPendingMatches();
});

