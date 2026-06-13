import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;
import '../../features/auth/auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _lime = Color(0xFFCCFF00);
  static const _bg   = Color(0xFF0A0A0A);

  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _tagCtrl;
  late final AnimationController _dotCtrl;
  late final AnimationController _shimCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset>  _textSlide;
  late final Animation<double> _tagFade;
  late final Animation<double> _shimmer;

  bool _navigated   = false;
  bool _animDone    = false;
  bool _initDone    = false;
  bool _authDone    = false;
  AuthState? _pendingAuth;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    // ① ciężka inicjalizacja w tle — równolegle z animacją
    _doHeavyInit();

    // ② animacja splash
    _runSequence();

    // ③ jeśli auth już rozwiązany przed buildem
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AuthBloc>().state;
      if (s is! AuthLoading) _onAuthResolved(s);
    });
  }

  void _setupAnimations() {
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0, 0.45, curve: Curves.easeOut)));

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.28), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _tagCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _tagFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));

    _shimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _shimmer  = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimCtrl, curve: Curves.easeInOut));

    _dotCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  Future<void> _doHeavyInit() async {
    // MobileAds w tle — nie blokuje nawigacji, nie potrzebne przed loginem
    admob.MobileAds.instance.initialize().ignore();
    _initDone = true;
    _tryNavigate();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await _tagCtrl.forward();
    // minimum 2s widzialności splash po animacji
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    _animDone = true;
    _tryNavigate();
  }

  void _onAuthResolved(AuthState state) {
    _pendingAuth = state;
    _authDone    = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    // nawiguj tylko gdy: animacja skończyła + init skończyła + auth znany
    if (!_animDone || !_initDone || !_authDone) return;
    if (_navigated || !mounted) return;
    _navigated = true;
    final s = _pendingAuth ?? context.read<AuthBloc>().state;
    if (s is AuthAuthenticated) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _dotCtrl.dispose();
    _shimCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────── BUILD ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (ctx, state) {
          if (state is! AuthLoading) _onAuthResolved(state);
        },
        child: Stack(
          children: [
            // dot grid
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

            // radial glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _logoFade,
                builder: (_, __) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.12),
                      radius: 0.72,
                      colors: [
                        _iconBlue.withValues(alpha: 0.12 * _logoFade.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── centre column ─────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // logo box
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                        opacity: _logoFade, child: _logoBox()),
                  ),
                  const SizedBox(height: 34),
                  // wordmark
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                        opacity: _textFade, child: _wordmark()),
                  ),
                  const SizedBox(height: 16),
                  // tagline shimmer
                  FadeTransition(opacity: _tagFade, child: _tagline()),
                ],
              ),
            ),

            // bottom dots
            Positioned(
              bottom: 56,
              left: 0, right: 0,
              child: FadeTransition(opacity: _tagFade, child: _dots()),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo box ─────────────────────────────────────────
  // kolor akcentu z logo — ciepły złoty żółty
  static const _iconBlue   = Color(0xFFF5C400);
  static const _iconOrange = Color(0xFFE8A020);

  Widget _logoBox() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        shape: BoxShape.circle,
        boxShadow: [
          // złoty glow główny
          BoxShadow(
              color: _iconBlue.withValues(alpha: 0.55),
              blurRadius: 52,
              spreadRadius: 4),
          // ciepły poświat zewnętrzny
          BoxShadow(
              color: _iconOrange.withValues(alpha: 0.22),
              blurRadius: 90,
              spreadRadius: 8),
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/icons/ui/typerly-icon-app.png',
          width: 90,
          height: 90,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ── TYPERLY wordmark ──────────────────────────────────
  Widget _wordmark() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontFamily: 'Archivo',
          fontWeight: FontWeight.w900,
          fontSize: 44,
          letterSpacing: 4,
          height: 1,
        ),
        children: [
          TextSpan(text: 'TYPE', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'RLY', style: TextStyle(color: _iconBlue)),
        ],
      ),
    );
  }

  // ── tagline z shimmerem ───────────────────────────────
  Widget _tagline() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => ShaderMask(
        shaderCallback: (b) => LinearGradient(
          colors: const [Color(0xFF555555), Colors.white, Color(0xFF555555)],
          stops: [
            (_shimmer.value - 0.45).clamp(0.0, 1.0),
            _shimmer.value.clamp(0.0, 1.0),
            (_shimmer.value + 0.45).clamp(0.0, 1.0),
          ],
        ).createShader(b),
        child: child,
      ),
      child: const Text(
        'TYPUJ  ·  RYWALIZUJ  ·  WYGRYWAJ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.8,
        ),
      ),
    );
  }

  // ── animowane kropki loading ──────────────────────────
  Widget _dots() {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final t = ((_dotCtrl.value - i / 3) % 1 + 1) % 1;
          final s = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 7 * s, height: 7 * s,
            decoration: BoxDecoration(
              color: _iconBlue.withValues(alpha: (0.3 + 0.7 * s).clamp(0, 1)),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

// ── Logo painter: T + checkmark ─────────────────────────────────────────────
class _LogoPainter extends CustomPainter {
  final Color color;
  const _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // crossbar
    final barH  = s.height * 0.14;
    final barRR = Radius.circular(barH / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, s.width, barH, barRR),
      fill,
    );
    // stem
    final stemW = s.width * 0.16;
    final stemL = (s.width - stemW) / 2;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        stemL, barH, stemL + stemW, s.height * 0.65,
        bottomLeft: Radius.circular(stemW / 2),
        bottomRight: Radius.circular(stemW / 2),
      ),
      fill,
    );
    // checkmark (bottom right)
    final cx = s.width * 0.72, cy = s.height * 0.78;
    final r  = s.width * 0.22;
    final path = Path()
      ..moveTo(cx - r * 0.7, cy)
      ..lineTo(cx - r * 0.15, cy + r * 0.55)
      ..lineTo(cx + r * 0.7, cy - r * 0.55);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_LogoPainter o) => o.color != color;
}

// ── Dot grid background ──────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFCCFF00).withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;
    const sp = 28.0;
    for (double x = sp; x < size.width;  x += sp)
      for (double y = sp; y < size.height; y += sp)
        canvas.drawCircle(Offset(x, y), 1.4, p);
  }
  @override
  bool shouldRepaint(_) => false;
}
