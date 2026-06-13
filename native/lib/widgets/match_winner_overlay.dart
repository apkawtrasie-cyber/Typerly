import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Wywołaj przez showMatchWinnerOverlay() — auto-dismiss po 4s lub tap.
Future<void> showMatchWinnerOverlay({
  required BuildContext context,
  required String winnerName,
  required int homeScore,
  required int awayScore,
  required String homeTeamName,
  required String awayTeamName,
  bool isFinal = false,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => _WinnerOverlay(
      winnerName: winnerName,
      homeScore: homeScore,
      awayScore: awayScore,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      isFinal: isFinal,
    ),
  );
}

class _WinnerOverlay extends StatefulWidget {
  final String winnerName;
  final int homeScore;
  final int awayScore;
  final String homeTeamName;
  final String awayTeamName;
  final bool isFinal;

  const _WinnerOverlay({
    required this.winnerName,
    required this.homeScore,
    required this.awayScore,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.isFinal,
  });

  @override
  State<_WinnerOverlay> createState() => _WinnerOverlayState();
}

class _WinnerOverlayState extends State<_WinnerOverlay> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    if (widget.isFinal) _confetti.play();
    // Auto-dismiss po 4.5s
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
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
            // Konfetti (tylko dla Finału)
            if (widget.isFinal)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 40,
                  maxBlastForce: 40,
                  minBlastForce: 15,
                  emissionFrequency: 0.05,
                  gravity: 0.3,
                  colors: const [
                    Color(0xFFE8FF00),
                    Colors.white,
                    Colors.orange,
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                  ],
                ),
              ),

            // Centralna karta
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animacja pucharu
                Lottie.asset(
                  'assets/lottie/45c73c96-1179-11ee-bbf8-1314ff4d4795.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFE8FF00),
                    size: 100,
                  ),
                ),
                const SizedBox(height: 8),

                // Wynik meczu
                Text(
                  '${widget.homeTeamName}  ${widget.homeScore} : ${widget.awayScore}  ${widget.awayTeamName}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Zwycięzca
                if (widget.winnerName.isNotEmpty) ...[
                  Text(
                    widget.winnerName,
                    style: const TextStyle(
                      color: Color(0xFFE8FF00),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.isFinal)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'MISTRZ TURNIEJU',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 32),
                const Text(
                  'Dotknij aby zamknąć',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
