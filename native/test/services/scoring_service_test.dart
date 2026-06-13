import 'package:flutter_test/flutter_test.dart';
import 'package:typerly/services/scoring_service.dart';

void main() {
  group('ScoringService.calculatePoints', () {
    // ── 3 punkty: dokładny wynik ────────────────────────────────────────────

    test('dokładny wynik (3:1 vs 3:1) → 3 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 3, predictAway: 1, realHome: 3, realAway: 1),
        equals(3),
      );
    });

    test('dokładny wynik (0:0 remis) → 3 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 0, realHome: 0, realAway: 0),
        equals(3),
      );
    });

    test('dokładny wynik (0:1) → 3 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 1, realHome: 0, realAway: 1),
        equals(3),
      );
    });

    // ── 2 punkty: ta sama różnica bramek ────────────────────────────────────

    test('różnica bramek (3:1 vs 2:0) — obaj +2 → 2 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 3, predictAway: 1, realHome: 2, realAway: 0),
        equals(2),
      );
    });

    test('różnica bramek (0:1 vs 1:2) — oba wynik Afryki +1 → 2 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 1, realHome: 1, realAway: 2),
        equals(2),
      );
    });

    test('poprawny remis, inny wynik (1:1 vs 2:2) → 2 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 1, predictAway: 1, realHome: 2, realAway: 2),
        equals(2),
      );
    });

    test('poprawny remis (0:0 vs 1:1) → 2 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 0, realHome: 1, realAway: 1),
        equals(2),
      );
    });

    // ── 1 punkt: poprawna tendencja, zła różnica ────────────────────────────

    test('tendencja (3:1 vs 2:1) — wygrał ten sam, inna różnica → 1 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 3, predictAway: 1, realHome: 2, realAway: 1),
        equals(1),
      );
    });

    test('tendencja (0:1 vs 0:2) — wygrał away, inna różnica → 1 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 1, realHome: 0, realAway: 2),
        equals(1),
      );
    });

    test('tendencja (2:0 vs 3:0) — wygrał home, różnica 2 vs 3 → 1 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 2, predictAway: 0, realHome: 3, realAway: 0),
        equals(1),
      );
    });

    // ── 0 punktów: pudło ────────────────────────────────────────────────────

    test('pudło: obstawiał wygraną, był remis (0:1 vs 1:1) → 0 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 1, realHome: 1, realAway: 1),
        equals(0),
      );
    });

    test('pudło: obstawiał wygraną away, wygrał home (0:1 vs 1:0) → 0 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 0, predictAway: 1, realHome: 1, realAway: 0),
        equals(0),
      );
    });

    test('pudło: obstawiał remis, wygrał home (1:1 vs 2:0) → 0 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 1, predictAway: 1, realHome: 2, realAway: 0),
        equals(0),
      );
    });

    test('pudło: obstawiał home, wygrał away (2:1 vs 1:3) → 0 pkt', () {
      expect(
        ScoringService.calculatePoints(
            predictHome: 2, predictAway: 1, realHome: 1, realAway: 3),
        equals(0),
      );
    });
  });
}
