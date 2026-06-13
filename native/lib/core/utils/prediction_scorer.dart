/// Algorytm punktacji typów piłkarskich Typerly
///
/// +3 — dokładny wynik (np. 2:1 → 2:1)
/// +2 — różnica bramek zgadza się (np. 2:0 → 3:0 — oba gospodarze o 2)
/// +1 — tendencja poprawna (wygrana / remis / przegrana)
///  0 — nic się nie zgadza
class PredictionScorer {
  const PredictionScorer._();

  static int calculate({
    required int predictedHome,
    required int predictedAway,
    required int actualHome,
    required int actualAway,
  }) {
    // 1. Dokładny wynik
    if (predictedHome == actualHome && predictedAway == actualAway) return 3;

    final predDiff   = predictedHome - predictedAway;
    final actualDiff = actualHome    - actualAway;

    // 2. Taka sama różnica bramek (ten sam wynik tendencji + liczba)
    if (predDiff == actualDiff) return 2;

    // 3. Sama tendencja (W/D/L)
    if (_tendency(predDiff) == _tendency(actualDiff)) return 1;

    return 0;
  }

  static String label(int points) {
    switch (points) {
      case 3:  return 'Dokładny wynik!';
      case 2:  return 'Różnica bramek!';
      case 1:  return 'Tendencja!';
      default: return 'Tym razem nie';
    }
  }

  static _Tendency _tendency(int diff) {
    if (diff > 0) return _Tendency.homeWin;
    if (diff < 0) return _Tendency.awayWin;
    return _Tendency.draw;
  }
}

enum _Tendency { homeWin, draw, awayWin }
