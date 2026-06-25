import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/routine_repository.dart';
import 'data/services/day_history_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/routine_local_service.dart';
import 'data/services/supabase_profile_service.dart';
import 'domain/models/user_profile.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/activity/views/status_composer_view.dart';
import 'ui/features/auth/views/login_view.dart';
import 'ui/features/friends/view_models/feed_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/onboarding/views/onboarding_view.dart';
import 'ui/features/routine/view_models/routine_view_model.dart';
import 'ui/features/social/view_models/social_hub_view_model.dart';
import 'ui/features/auth/views/update_password_view.dart';
import 'ui/features/social/views/chat_view.dart';

const _supabaseUrl = 'https://trzfhrrksvdemowfaodi.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyemZocnJrc3ZkZW1vd2Zhb2RpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzNTY4MzIsImV4cCI6MjA5NTkzMjgzMn0.lyfhSabrWi2EkjTTm904wuXAFLOQhG2Skf03X1oAkY0';

final _navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Firebase must initialize before anything else
  await Firebase.initializeApp();

  // Register background message handler (must be top-level function)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  // Notification init can be slow on iOS (waits for APNs token) — run it
  // without blocking so runApp() is reached immediately and the UI appears.
  NotificationService.instance.init().then((_) {
    _setupNotificationRouting();
    // Clear badge when app starts
    NotificationService.instance.clearBadge();
  });

  // If session already exists (returning user), signedIn may not re-fire,
  // so we trigger the FCM token save directly here as well.
  if (Supabase.instance.client.auth.currentSession != null) {
    NotificationService.instance.ensureFcmToken();
  }

  // Listener global de auth — funciona independente de qual tela está aberta
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final nav = _navKey.currentState;
    if (nav == null) return;

    switch (data.event) {
      case AuthChangeEvent.signedIn:
        SupabaseProfileService.instance.ensureProfile();
        NotificationService.instance.ensureFcmToken();
        hasSeenOnboarding().then((seen) {
          nav.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => seen ? const HomeView() : const OnboardingView(),
            ),
            (_) => false,
          );
        });
      case AuthChangeEvent.passwordRecovery:
        nav.push(MaterialPageRoute(
          builder: (_) => const UpdatePasswordView(),
          fullscreenDialog: true,
        ));
      case AuthChangeEvent.signedOut:
        NotificationService.instance.clearFcmToken();
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (_) => false,
        );
      default:
        break;
    }
  });

  final prefs = await SharedPreferences.getInstance();
  DayHistoryService.instance.init(prefs);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0B12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final routineService = RoutineLocalService();
  final routineRepository = RoutineRepository(localService: routineService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RoutineViewModel(repository: routineRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => FeedViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => SocialHubViewModel(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Wires notification taps to in-app navigation via the global navigator key.
void _setupNotificationRouting() {
  final notif = NotificationService.instance;

  notif.onMessageTap = (senderId, senderName) async {
    final nav = _navKey.currentState;
    if (nav == null) return;
    // Build a minimal UserProfile for the sender (enough for ChatView)
    final profile = UserProfile(
      id: senderId,
      name: senderName,
      avatarUrl: '',
      routine: const [],
    );
    nav.push(MaterialPageRoute(builder: (_) => ChatView(friend: profile)));
  };

  notif.onExpiryTap = () {
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => const StatusComposerView(initialTab: ComposerTab.now),
      fullscreenDialog: true,
    ));
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      navigatorKey: _navKey,
      home: const _AuthGate(),
      builder: (context, child) {
        // On iPad, constrain the UI to a phone-width column so the app looks
        // and behaves the same as on iPhone without any per-screen changes.
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 430 || child == null) return child ?? const SizedBox();
        return Center(
          child: SizedBox(
            width: 430,
            child: ClipRect(child: child),
          ),
        );
      },
    );
  }
}

/// Tela inicial — define a rota correta com base na sessão e no onboarding.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate>
    with WidgetsBindingObserver {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    // Always show splash for at least 1.5s
    final session = Supabase.instance.client.auth.currentSession;
    final futures = await Future.wait([
      Future.value(session),
      if (session != null) hasSeenOnboarding() else Future.value(false),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted) return;
    final Widget dest;
    if (session == null) {
      dest = const LoginView();
    } else {
      final seen = futures[1] as bool;
      dest = seen ? const HomeView() : const OnboardingView();
    }
    setState(() => _destination = dest);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.clearBadge();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_destination != null) return _destination!;
    return const _SplashScreen();
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fadeIn =
      CurvedAnimation(parent: _enter, curve: Curves.easeOut);
  late final Animation<double> _slideIn = Tween<double>(begin: 24, end: 0)
      .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _glow.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0B12);
    const primary = Color(0xFF7C5CFC);
    const secondary = Color(0xFFE040FB);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Glow background
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => CustomPaint(
              painter: _GlowPainter(
                t: _glow.value,
                primary: primary,
                secondary: secondary,
              ),
            ),
          ),

          // Center content
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: AnimatedBuilder(
                animation: _slideIn,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _slideIn.value),
                  child: child,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 300,
                      height: 300,
                    ),

                    const SizedBox(height: 24),

                    // App name
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [primary, secondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: const Text(
                        'VibeTime',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'O que você está fazendo agora?',
                      style: TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Subtle dots loader at bottom
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeIn,
              child: _DotsLoader(color: primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.t,
    required this.primary,
    required this.secondary,
  });

  final double t;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;

    final r1 = 180.0 + t * 40;
    canvas.drawCircle(
      Offset(cx, cy),
      r1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: 0.18 + t * 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r1)),
    );

    final r2 = 120.0 + (1 - t) * 30;
    canvas.drawCircle(
      Offset(cx + 60, cy - 40),
      r2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            secondary.withValues(alpha: 0.12 + (1 - t) * 0.06),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(cx + 60, cy - 40), radius: r2)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

class _DotsLoader extends StatefulWidget {
  const _DotsLoader({required this.color});
  final Color color;

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
            final alpha = (0.2 + 0.8 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: alpha),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
