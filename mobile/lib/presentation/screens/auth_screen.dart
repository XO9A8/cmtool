import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
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
      final msg = e.response?.data?['error']?['message'] ?? 'Network Error ($e)';
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Animation
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF090A0F), Color(0xFF13151F)],
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
                color: const Color(0xFF00E5FF).withOpacity(0.10),
                boxShadow: const [BoxShadow(color: Color(0xFF00E5FF), blurRadius: 60)],
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
                color: const Color(0xFFB000FF).withOpacity(0.10),
                boxShadow: const [BoxShadow(color: Color(0xFFB000FF), blurRadius: 60)],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 5.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
          ),
          
          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB000FF), Color(0xFF00E5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.5),
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
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
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
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                  color: Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
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
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFB000FF), Color(0xFF00E5FF)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFB000FF).withOpacity(0.4),
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
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: _isLogin
                                ? "No access credentials? "
                                : 'Credentials acquired? ',
                          ),
                          TextSpan(
                            text: _isLogin ? 'Request Access' : 'Authenticate',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: 800.ms),
                ],
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
      prefixIcon: Icon(icon, color: const Color(0xFF00E5FF), size: 22),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
      ),
    );
  }
}
