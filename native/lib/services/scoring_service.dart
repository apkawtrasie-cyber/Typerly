/// Algorytm punktacji typów: 3 / 2 / 1 / 0
///
/// 3 pkt – dokładny wynik
/// 2 pkt – ta sama różnica bramek (= poprawny zwycięzca + dokładna różnica;
///         lub poprawny remis przy innym dokładnym wyniku remisowym)
/// 1 pkt – poprawna tendencja (kto wygrał lub obaj zremisowali), ale inna różnica
/// 0 pkt – pudło (zły kierunek)
///
/// Logika musi być identyczna z funkcją PostgreSQL `calculate_match_points`
/// w migracji 003_scoring.sql.
class ScoringService {
  ScoringService._();

  static int calculatePoints({
    required int predictHome,
    required int predictAway,
    required int realHome,
    required int realAway,
  }) {
    // 3 pkt: dokładny wynik
    if (predictHome == realHome && predictAway == realAway) {
      return 3;
    }

    final predDiff = predictHome - predictAway;
    final realDiff = realHome - realAway;

    // 2 pkt: ta sama różnica bramek
    if (predDiff == realDiff) {
      return 2;
    }

    // 1 pkt: poprawna tendencja
    if (_sign(predDiff) == _sign(realDiff)) {
      return 1;
    }

    return 0;
  }

  static int _sign(int x) => x > 0 ? 1 : (x < 0 ? -1 : 0);
}
