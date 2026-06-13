import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/utils/prediction_scorer.dart';

/// Wyświetla overlay z wynikiem typowania po zakończeniu meczu.
/// - points > 0 → pulsujący puchar + konfetti + nick + punkty + odznaka
/// - points == 0 → pełnoekranowe konfetti + tarcza pocieszenia + "Zdobywasz odznakę!"
Future<void> showPredictionResultOverlay({
  required BuildContext context,
  required String username,
  required int points,
  required int predictedHome,
  required int predictedAway,
  required int actualHome,
  required int actualAway,
  String? badgeName,     // np. 'Snajper 🎯'
  String? badgeRarity,   // common / rare / epic / legendary
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.82),
    builder: (_) => _PredictionResultOverlay(
      username: username,
      points: points,
      predictedHome: predictedHome,
      predictedAway: predictedAway,
      actualHome: actualHome,
      actualAway: actualAway,
      badgeName: badgeName,
      badgeRarity: badgeRarity,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
class _PredictionResultOverlay extends StatefulWidget {
  final String username;
  final int points, predictedHome, predictedAway, actualHome, actualAway;
  final String? badgeName;
  final String? badgeRarity;

  const _PredictionResultOverlay({
    required this.username,
    required this.points,
    required this.predictedHome,
    required this.predictedAway,
    required this.actualHome,
    required this.actualAway,
    this.badgeName,
    this.badgeRarity,
  });

  @override
  State<_PredictionResultOverlay> createState() =>
      _PredictionResultOverlayState();
}

class _PredictionResultOverlayState extends State<_PredictionResultOverlay>
    with TickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _fadeCtrl;

  bool _showLottie = false; // tarcza pocieszenia pojawia się po 1s

  static const _gold   = Color(0xFFF5C400);
  static const _red    = Color(0xFFFF4444);

  @override
  void initState() {
    super.initState();

    _confetti = ConfettiController(duration: const Duration(seconds: 5))
      ..play();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();

    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.90, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (widget.points == 0) {
      // tarcza pocieszenia wyskakuje po 1 s
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showLottie = true);
      });
    }

    // Auto-dismiss po 5.5 s
    Future.delayed(const Duration(milliseconds: 5500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── kolory wg punktów ──────────────────────────────────
  Color get _accentColor {
    switch (widget.points) {
      case 3:  return _gold;
      case 2:  return const Color(0xFF44AAFF);
      case 1:  return const Color(0xFF66DD66);
      default: return _red;
    }
  }

  List<Color> get _confettiColors {
    if (widget.points == 0) {
      return [_red, Colors.white, Colors.orange, Colors.purple];
    }
    return [_gold, Colors.white, const Color(0xFF44AAFF), Colors.green, Colors.pink];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Konfetti ──────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: widget.points > 0 ? 50 : 35,
                maxBlastForce: 50,
                minBlastForce: 20,
                emissionFrequency: 0.04,
                gravity: 0.25,
                colors: _confettiColors,
                createParticlePath: _drawStar,
              ),
            ),

            // ── Treść ─────────────────────────────────────
            FadeTransition(
              opacity: _fadeCtrl,
              child: widget.points > 0
                  ? _buildWinContent()
                  : _buildLoseContent(),
            ),

            // ── Dotknij aby zamknąć ───────────────────────
            Positioned(
              bottom: 48,
              child: Text(
                'Dotknij aby zamknąć',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WYGRANA: puchar + punkty ───────────────────────────
  Widget _buildWinContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Duży pulsujący puchar — ~połowa ekranu
        ScaleTransition(
          scale: _pulse,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.72,
            height: MediaQuery.of(context).size.width * 0.72,
            child: Lottie.asset(
              'assets/lottie/45c73c96-1179-11ee-bbf8-1314ff4d4795.json',
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, __, ___) => Icon(
                Icons.emoji_events,
                color: _gold,
                size: MediaQuery.of(context).size.width * 0.55,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Nick użytkownika
        Text(
          widget.username,
          style: TextStyle(
            color: _accentColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Duże punkty
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accentColor.withOpacity(0.6), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                '+${widget.points} ${widget.points == 1 ? "punkt" : widget.points < 5 ? "punkty" : "punktów"}',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                PredictionScorer.label(widget.points),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Twój typ → Wynik
        Text(
          'Twój typ: ${widget.predictedHome}:${widget.predictedAway}  •  Wynik: ${widget.actualHome}:${widget.actualAway}',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),

        // Odznaka (jeśli zdobyta)
        if (widget.badgeName != null) ...[
          const SizedBox(height: 20),
          _BadgeChip(name: widget.badgeName!, rarity: widget.badgeRarity ?? 'common'),
        ],
      ],
    );
  }

  // ── PRZEGRANA: tarcza pocieszenia ─────────────────────
  Widget _buildLoseContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Tarcza pocieszenia — wyskakuje z centrum po 1 s
        AnimatedScale(
          scale: _showLottie ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.78,
            height: MediaQuery.of(context).size.width * 0.78,
            child: Lottie.asset(
              'assets/lottie/gwiazda.json',
              fit: BoxFit.contain,
              repeat: false,
              errorBuilder: (_, __, ___) => Icon(
                Icons.shield_outlined,
                color: _red.withOpacity(0.7),
                size: MediaQuery.of(context).size.width * 0.5,
              ),
            ),
          ),
        ),

        AnimatedOpacity(
          opacity: _showLottie ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                widget.username,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Nie tym razem — gwiazda za udział! ⭐',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Każdy typ to krok do mistrzostwa 🚀',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Twój typ: ${widget.predictedHome}:${widget.predictedAway}  •  Wynik: ${widget.actualHome}:${widget.actualAway}',
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Odznaka
              const SizedBox(height: 16),
              _BadgeChip(
                name: widget.badgeName ?? 'Gwiazda ⭐',
                rarity: widget.badgeRarity ?? 'common',
                subtitle: 'Zdobywasz odznakę!',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Badge chip — animowany z poświatą wg rzadkości
// ─────────────────────────────────────────────────────────────────
class _BadgeChip extends StatefulWidget {
  final String name;
  final String rarity;
  final String? subtitle;
  const _BadgeChip({required this.name, required this.rarity, this.subtitle});

  @override
  State<_BadgeChip> createState() => _BadgeChipState();
}

class _BadgeChipState extends State<_BadgeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  Color get _rarityColor {
    switch (widget.rarity) {
      case 'legendary': return const Color(0xFFFF9500);
      case 'epic':      return const Color(0xFFAA44FF);
      case 'rare':      return const Color(0xFF44AAFF);
      default:          return const Color(0xFF88CC88);
    }
  }

  String get _rarityLabel {
    switch (widget.rarity) {
      case 'legendary': return 'LEGENDARNY';
      case 'epic':      return 'EPICKI';
      case 'rare':      return 'RZADKI';
      default:          return 'ZWYKŁY';
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Column(
        children: [
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.subtitle!,
                style: TextStyle(
                  color: _rarityColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _rarityColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: _rarityColor.withOpacity(0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _rarityColor.withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.name,
                    style: TextStyle(
                      color: _rarityColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rarityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_rarityLabel,
                      style: TextStyle(
                        color: _rarityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Gwiazda jako kształt konfetti
Path _drawStar(Size size) {
  final path = Path();
  final cx = size.width / 2;
  final cy = size.height / 2;
  const n = 5;
  final outerR = size.width / 2;
  final innerR = outerR * 0.45;
  for (int i = 0; i < n * 2; i++) {
    final angle = (math.pi / n) * i - math.pi / 2;
    final r = i.isEven ? outerR : innerR;
    final x = cx + r * math.cos(angle);
    final y = cy + r * math.sin(angle);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  path.close();
  return path;
}
