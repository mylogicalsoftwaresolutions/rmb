import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart' show ApiException;
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  final Function(String name, String role, String mobile) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMsg;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedMobile();
  }

  Future<void> _loadSavedMobile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMobile = prefs.getString('saved_mobile');
    if (!mounted || savedMobile == null) return;
    setState(() => _mobileController.text = savedMobile);
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text.trim();

    if (mobile.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter a valid mobile number';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await AuthService.login(mobile, password).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw ApiException(
            'The server is taking too long to respond. Please check your connection and try again.',
          );
        },
      );
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_mobile', mobile);
      } else {
        await prefs.remove('saved_mobile');
      }

      // Parse login.php: { success, user_id, user: { display_name, role_name } }
      final userData = response['user'] is Map
          ? Map<String, dynamic>.from(response['user'] as Map)
          : <String, dynamic>{};

      final String name = userData['display_name']?.toString() ??
          userData['first_name']?.toString() ??
          'Member';
      final String role = userData['role_name']?.toString() ??
          userData['role_slug']?.toString() ??
          'member';
      final String userMobile = userData['mobile']?.toString() ?? mobile;

      // Prefetch dashboard data immediately while the app transitions to the member shell
      unawaited(DashboardService.getDashboardData(refresh: true));

      widget.onLogin(name, role, userMobile);
    } catch (e) {
      debugPrint('Login Exception: $e');
      if (!mounted) return;
      setState(() {
        _errorMsg = e is ApiException
            ? e.message.trim()
            : e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Login screen displays the rich blue theme by default
    final isDark = AppColors.isDarkMode.value;
    final goldColor = AppColors.secondary;
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg : Colors.white,
      body: Stack(
        children: [
          // Background - Pure White in White Theme, Gradient in Dark Theme
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.bg : Colors.white,
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        AppColors.card,
                        AppColors.bg,
                        AppColors.bg,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
            ),
          ),
          // Glow effects (Dark theme only)
          if (isDark)
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withValues(alpha: 0.18),
                      blurRadius: 90,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
          if (isDark)
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.card.withValues(alpha: 0.4),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

          // Main Login Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: goldColor,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : const Color(0x14000000),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // RMB Official Logo (Circular)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: goldColor,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? goldColor.withValues(alpha: 0.3)
                                  : primaryColor.withValues(alpha: 0.12),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title & Subtitle matching website
                      Text(
                        'RMB',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? goldColor : primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member Portal Sign In',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFFD1E2F7)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (_errorMsg != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            border: Border.all(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Mobile Number Field
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Member Mobile Number',
                          style: TextStyle(
                            color: isDark ? goldColor : primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: goldColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? goldColor.withValues(alpha: 0.1)
                                    : primaryColor.withValues(alpha: 0.08),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(11),
                                  bottomLeft: Radius.circular(11),
                                ),
                              ),
                              child: Icon(
                                Icons.phone_android_outlined,
                                color: isDark ? goldColor : primaryColor,
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _mobileController,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter mobile number',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? AppColors.textMuted
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password',
                          style: TextStyle(
                            color: isDark ? goldColor : primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: goldColor,
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter password',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.textMuted
                                  : const Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark
                                    ? AppColors.textMuted
                                    : const Color(0xFF6B7280),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: isDark ? goldColor : primaryColor,
                              checkColor: Colors.white,
                              onChanged: (value) {
                                setState(() => _rememberMe = value ?? true);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember mobile number',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF374151),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Sign In Button
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppColors.secondary, const Color(0xFFE5A50A)]
                                : [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? goldColor.withValues(alpha: 0.4)
                                  : primaryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleSignIn,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        isDark ? AppColors.card : Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.login,
                                  size: 20,
                                ),
                          label: Text(
                            _isLoading ? 'Signing In...' : 'Sign In as Member',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Members are created by chapter administrators.',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textMuted
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
