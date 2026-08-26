import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String? _errorMessage;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.length < 6) {
      setState(() => _errorMessage = 'Username required & Password > 5 chars');
      return;
    }

    setState(() { _loading = true; _errorMessage = null; });

    try {
      final auth = ref.read(authStateProvider.notifier);
      final client = ref.read(apiClientProvider);

      if (_isLogin) {
        await auth.login(client, username, password);
      } else {
        await auth.register(client, username, password);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['error']?['message'] ?? 'Network Error ($e)';
      setState(() => _errorMessage = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authStateProvider.notifier);
      final client = ref.read(apiClientProvider);
      await auth.signInWithGoogle(client);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['error']?['message'] ?? 'Network Error ($e)';
      setState(() => _errorMessage = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // Background Gradient Animation
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.navy, AppColors.surface, AppColors.navy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Animated Glowing Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
                boxShadow: [BoxShadow(color: AppColors.gold, blurRadius: 80)],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 4.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
          ),
          Positioned(
            bottom: -150,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
                boxShadow: [BoxShadow(color: AppColors.primary, blurRadius: 80)],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 5.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
          ),
          
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.paper, AppColors.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 25,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sports_soccer, color: Colors.white, size: 45),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'eFootball Manager',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.5, end: 0),
                  
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'INITIATE SESSION' : 'REGISTER NEW PLAYER',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fade(delay: 400.ms),
                  
                  const SizedBox(height: 40),

                  // Glassmorphism Form Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _usernameCtrl,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              decoration: _inputDecoration('Username', Icons.person_outline),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              decoration: _inputDecoration('Password', Icons.lock_outline),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.lossRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.lossRed.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: AppColors.lossRed, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(color: AppColors.lossRed, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fade().slideY(begin: -0.2, end: 0),
                            ],
                            const SizedBox(height: 30),
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary, AppColors.gold],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                          )
                                        : Text(
                                            _isLogin ? 'CONNECT' : 'INITIALIZE',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              letterSpacing: 1.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ).animate().fade(delay: 600.ms).slideY(begin: 0.2, end: 0),
                            
                            const SizedBox(height: 20),
                            
                            // OR Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1)),
                              ],
                            ).animate().fade(delay: 650.ms),

                            const SizedBox(height: 20),

                            // Google Sign-In Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _loading ? null : _submitGoogle,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                                      height: 20,
                                      width: 20,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'CONTINUE WITH GOOGLE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fade(delay: 700.ms).slideY(begin: 0.2, end: 0),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(delay: 500.ms).scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: 32),

                  // Toggle login / register
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                              text: _isLogin
                                  ? "No access credentials?  "
                                  : 'Credentials acquired?  ',
                            ),
                            TextSpan(
                              text: _isLogin ? 'Request Access' : 'Authenticate',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(delay: 800.ms),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: AppColors.gold, size: 22),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.gold, width: 1.5),
      ),
    );
  }
}
