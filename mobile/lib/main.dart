import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'presentation/theme/app_theme.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/h2h_screen.dart';
import 'presentation/screens/tournament_screen.dart';
import 'presentation/screens/clubs_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/player_profile_screen.dart';
import 'presentation/screens/admin_dispute_screen.dart';
import 'presentation/screens/game_guide_screen.dart';
import 'presentation/widgets/pending_verifications_modal.dart';
import 'presentation/providers/match_provider.dart';
import 'infrastructure/offline_sync_service.dart';
import 'infrastructure/update_service.dart';
import 'presentation/widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('Failed to set high refresh rate: $e');
    }
  }

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://ypsrkdefgbghvluuyynm.supabase.co'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg'),
  );

  runApp(const ProviderScope(child: EFootballApp()));
}

class EFootballApp extends StatelessWidget {
  const EFootballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eFootball Club Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
  bool _syncStarted = false;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(authStateProvider) != null) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;
    _isCheckingUpdate = true;
    
    try {
      final apiClient = ref.read(apiClientProvider);
      final updateService = UpdateService(apiClient);
      final updateInfo = await updateService.checkForUpdates();
      
      if (updateInfo.updateAvailable && updateInfo.serverVersion != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: !updateInfo.serverVersion!.forceUpdate,
          builder: (_) => UpdateDialog(versionInfo: updateInfo.serverVersion!),
        );
      }
    } finally {
      _isCheckingUpdate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider);

    if (userId == null) {
      _syncStarted = false;
      return const AuthScreen();
    }

    if (!_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ref.read(offlineSyncProvider).startAutoSync(ref);
        await _checkForUpdates();
      });
    }

    return const NavigationRootScreen();
  }
}

class NavigationRootScreen extends StatefulWidget {
  const NavigationRootScreen({super.key});

  @override
  State<NavigationRootScreen> createState() => _NavigationRootScreenState();
}

class _NavigationRootScreenState extends State<NavigationRootScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TournamentScreen(),
    GameGuideScreen(),
    ClubsScreen(),
    H2hScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.8),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_soccer,
                    color: Colors.black, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'eFootball CM',
                style: GoogleFonts.orbitron(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_unread_outlined,
                color: AppColors.cyan),
            tooltip: 'Pending Approvals',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const PendingVerificationsModal(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.gavel_outlined, color: AppColors.primary),
            tooltip: 'Admin Disputes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDisputeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profilePrefs = ref.watch(profilePreferencesProvider);
              final avatarData = getAvatarById(profilePrefs.safeAvatarGraphic);
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PlayerProfileScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: avatarData.gradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              avatarData.gradient.first.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: CircleAvatar(
                        backgroundColor: AppColors.background,
                        child: Icon(
                          avatarData.icon,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border:
              const Border(top: BorderSide(color: Colors.white10, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle:
              GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle:
              GoogleFonts.rajdhani(fontWeight: FontWeight.w600, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Tournaments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Guide',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Clubs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.compare_arrows_outlined),
              activeIcon: Icon(Icons.compare_arrows),
              label: 'H2H',
            ),
          ],
        ),
      ),
    );
  }
}
