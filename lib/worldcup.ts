import { Match, isFinished } from "./supabase";

export type StandingRow = {
  team: string;
  logo: string | null;
  played: number;
  won: number;
  draw: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
  goalDiff: number;
  points: number;
};

export type GroupTable = {
  letter: string;
  rows: StandingRow[];
  earliest: number; // do sortowania grup
};

/**
 * Wykrywa grupy fazy grupowej przez komponenty spójne grafu "kto z kim gra"
 * (w fazie grupowej każda drużyna gra tylko z 3 rywalami z tej samej grupy),
 * a następnie liczy tabelę: 3 pkt zwycięstwo, 1 remis, 0 porażka.
 */
export function computeGroupTables(matches: Match[]): GroupTable[] {
  // Mapa logo
  const logos = new Map<string, string | null>();
  for (const m of matches) {
    if (!logos.has(m.home_team_name)) logos.set(m.home_team_name, m.home_team_logo_url);
    if (!logos.has(m.away_team_name)) logos.set(m.away_team_name, m.away_team_logo_url);
  }

  // Graf sąsiedztwa
  const adj = new Map<string, Set<string>>();
  const add = (a: string, b: string) => {
    if (!adj.has(a)) adj.set(a, new Set());
    adj.get(a)!.add(b);
  };
  for (const m of matches) {
    if (m.home_team_name === "Unknown" || m.away_team_name === "Unknown") continue;
    add(m.home_team_name, m.away_team_name);
    add(m.away_team_name, m.home_team_name);
  }

  // Komponenty spójne (BFS)
  const seen = new Set<string>();
  const components: Set<string>[] = [];
  for (const t of adj.keys()) {
    if (seen.has(t)) continue;
    const comp = new Set<string>();
    const stack = [t];
    while (stack.length) {
      const x = stack.pop()!;
      if (seen.has(x)) continue;
      seen.add(x);
      comp.add(x);
      for (const n of adj.get(x) ?? []) if (!seen.has(n)) stack.push(n);
    }
    if (comp.size >= 3 && comp.size <= 5) components.push(comp); // grupy ~4 drużyny
  }

  // Najwcześniejszy mecz w komponencie → sortowanie / litery
  const earliestOf = (teams: Set<string>) => {
    let min = Infinity;
    for (const m of matches) {
      if (teams.has(m.home_team_name) && teams.has(m.away_team_name)) {
        min = Math.min(min, new Date(m.match_time).getTime());
      }
    }
    return min;
  };

  const groups = components
    .map(teams => ({ teams, earliest: earliestOf(teams) }))
    .sort((a, b) => a.earliest - b.earliest);

  const LETTERS = "ABCDEFGHIJKL".split("");

  return groups.map((g, idx) => {
    const stats = new Map<string, StandingRow>();
    for (const team of g.teams) {
      stats.set(team, {
        team, logo: logos.get(team) ?? null,
        played: 0, won: 0, draw: 0, lost: 0,
        goalsFor: 0, goalsAgainst: 0, goalDiff: 0, points: 0,
      });
    }

    for (const m of matches) {
      if (!g.teams.has(m.home_team_name) || !g.teams.has(m.away_team_name)) continue;
      if (!isFinished(m.status) || m.home_score == null || m.away_score == null) continue;
      const h = stats.get(m.home_team_name)!;
      const a = stats.get(m.away_team_name)!;
      h.played++; a.played++;
      h.goalsFor += m.home_score; h.goalsAgainst += m.away_score;
      a.goalsFor += m.away_score; a.goalsAgainst += m.home_score;
      if (m.home_score > m.away_score) { h.won++; h.points += 3; a.lost++; }
      else if (m.home_score < m.away_score) { a.won++; a.points += 3; h.lost++; }
      else { h.draw++; a.draw++; h.points++; a.points++; }
    }

    const rows = [...stats.values()].map(r => ({ ...r, goalDiff: r.goalsFor - r.goalsAgainst }));
    rows.sort((x, y) =>
      y.points - x.points ||
      y.goalDiff - x.goalDiff ||
      y.goalsFor - x.goalsFor ||
      x.team.localeCompare(y.team)
    );

    return { letter: LETTERS[idx] ?? `${idx + 1}`, rows, earliest: g.earliest };
  });
}
