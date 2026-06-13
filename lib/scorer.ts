// Punktacja typowania — identyczna jak w aplikacji Flutter (PredictionScorer)
// 3 = trafiony dokładny wynik
// 2 = trafiona różnica bramek
// 1 = trafiona tendencja (kto wygra / remis)
// 0 = pudło

export function calculatePoints(
  predictedHome: number,
  predictedAway: number,
  actualHome: number,
  actualAway: number,
): number {
  if (predictedHome === actualHome && predictedAway === actualAway) return 3;
  const predDiff = predictedHome - predictedAway;
  const actualDiff = actualHome - actualAway;
  if (predDiff === actualDiff) return 2;
  if (tendency(predDiff) === tendency(actualDiff)) return 1;
  return 0;
}

function tendency(diff: number): number {
  if (diff > 0) return 1;
  if (diff < 0) return -1;
  return 0;
}

export function pointsLabel(points: number): string {
  switch (points) {
    case 3: return "DOKŁADNY WYNIK!";
    case 2: return "TRAFIONA RÓŻNICA";
    case 1: return "TRAFIONA TENDENCJA";
    default: return "PUDŁO";
  }
}

// Odznaka za liczbę punktów — ID zgodne z tabelą badge_definitions w Supabase
export type BadgeInfo = { id: string; name: string; icon: string; rarity: string };

export function badgeFor(points: number): BadgeInfo {
  switch (points) {
    case 3: return { id: "exact_score", name: "Snajper",  icon: "🎯", rarity: "rare" };
    case 2: return { id: "goal_diff",   name: "Strateg",  icon: "⚡", rarity: "common" };
    case 1: return { id: "tendency",    name: "Analityk", icon: "📊", rarity: "common" };
    // Pudło → odznaka pocieszenia (Tarcza) — taka sama nagroda jak przy wygranej
    default: return { id: "consolation", name: "Tarcza",  icon: "🛡️", rarity: "common" };
  }
}
