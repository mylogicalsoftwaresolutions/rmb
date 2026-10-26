import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/member_shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';
import 'services/auth_service.dart';
import 'widgets/app_error_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    // Register before runApp; doing this later left a startup window where a
    // mobile push could arrive without a background handler.
    registerFirebaseBackgroundHandler();
    // Enforce edge-to-edge system UI layout for Android 15+ and modern devices
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  AppColors.isDarkMode.value =
      true; // Default: Blue theme with rich blue background & gold accents

  // Last line of defence against a white screen.
  //
  // ErrorWidget.builder only catches *build/layout* failures. An exception
  // thrown from a build callback, an async gap, or a plugin channel leaves the
  // previous route in place, which on a tab shell can be a blank page with no
  // way out. The guards below cover the two common sources - a failed build
  // above the shell, and an unhandled async error - so a bad screen always
  // renders something the member can act on instead of nothing.
  ErrorWidget.builder = (details) {
    debugPrint('Uncaught build error: ${details.exception}');
    return AppErrorView(
      message: 'This screen ran into a problem. Please retry.',
      onRetry: () => runApp(const RMBConnectApp()),
    );
  };

  // Errors that reach a widget are already handled per-widget by
  // ErrorWidget.builder above. Only an error raised *before* the first frame
  // is escalated to a full-screen view - at that point there is no tree to
  // render into, so without this the app sits on a blank window.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (_firstFrameRendered) return;
    _reportFatal('The app could not start. Please restart it.');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    // Deliberately NOT escalated once the app is running. A single failed
    // future - a flaky image, a plugin hiccup, a request that already has its
    // own error handling - must not tear down a working screen and discard the
    // member's place in the app. Those are handled at their own call sites.
    if (_firstFrameRendered) return false;
    _reportFatal('The app could not start. Please restart it.');
    return true;
  };

  runApp(const RMBConnectApp());

  // Only an Android app is registered in Firebase (no Web app) - calling
  // Firebase.initializeApp() unguarded would crash the web build used for
  // local preview/testing. Referral push notifications are an Android-only
  // feature request, so this simply doesn't run there.
  if (!kIsWeb) {
    _pushInitialization = _initializePushNotifications();
  }
}

Future<void>? _pushInitialization;

/// Set once the first frame is on screen.
///
/// The global error handlers use this to tell "the app never came up" (worth
/// replacing the whole window) apart from "something failed while running"
/// (already handled wherever it happened, and must not discard the member's
/// navigation state).
bool _firstFrameRendered = false;

/// Renders a full-screen recoverable error over whatever is on screen.
///
/// Called from the global handlers above, which run outside the widget tree, so
/// it mounts a fresh [MaterialApp] rather than trying to reach an existing
/// navigator. Guarded so a second failure while already showing the error view
/// cannot recurse.
bool _fatalErrorShowing = false;

void _reportFatal(String message) {
  if (_fatalErrorShowing) return;
  _fatalErrorShowing = true;
  runApp(_FatalErrorApp(
    message: message,
    onRetry: () {
      _fatalErrorShowing = false;
      runApp(const RMBConnectApp());
    },
  ));
}

class _FatalErrorApp extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FatalErrorApp({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RMB Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.bg,
        ),
      ),
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: AppErrorView(message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}

Future<void> _initializePushNotifications() async {
  try {
    await initializeFirebase();
  } catch (e) {
    // A push-notification setup failure shouldn't block sign-in.
    debugPrint('Push notification setup failed: $e');
  }
}

class RMBConnectApp extends StatefulWidget {
  const RMBConnectApp({super.key});

  @override
  State<RMBConnectApp> createState() => _RMBConnectAppState();
}

class _RMBConnectAppState extends State<RMBConnectApp> {
  bool _showSplash = true;
  bool _isRestoringSession = true;
  Map<String, String>? _currentUser;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
    // Flipped after the first frame so the global handlers can tell a startup
    // failure from an ordinary runtime error. See [_firstFrameRendered].
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFrameRendered = true;
    });
  }

  Future<void> _restoreSession() async {
    Map<String, String>? savedUser;
    try {
      savedUser = await AuthService.restoreSession();
    } catch (error) {
      debugPrint('Could not restore saved session: $error');
    }
    if (!mounted) return;
    setState(() {
      _currentUser = savedUser;
      _isRestoringSession = false;
    });
    if (savedUser != null && !kIsWeb) {
      unawaited(_registerPushAfterLogin());
    }
  }

  void _handleSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  void _handleLogin(String name, String role, String mobile) {
    setState(() {
      _currentUser = {
        'name': name,
        'role': role,
        'mobile': mobile,
      };
    });
    if (!kIsWeb) unawaited(_registerPushAfterLogin());
  }

  Future<void> _registerPushAfterLogin() async {
    try {
      await _pushInitialization;
      await PushNotificationService.registerCurrentDevice();
    } catch (e) {
      debugPrint('Post-login push registration failed: $e');
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'RMB Connect',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppColors.bg,
            primaryColor: AppColors.primary,
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.bg,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    secondary: AppColors.secondary,
                    surface: AppColors.bg,
                  ),
            textTheme: GoogleFonts.outfitTextTheme(
              isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
            ),
            appBarTheme: AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              ),
            ),
            useMaterial3: true,
          ),
          home: _showSplash || _isRestoringSession
              ? SplashScreen(onSplashComplete: _handleSplashComplete)
              : _currentUser == null
                  ? LoginScreen(onLogin: _handleLogin)
                  : MemberShellScreen(
                      user: _currentUser!, onLogout: _handleLogout),
        );
      },
    );
  }
}
