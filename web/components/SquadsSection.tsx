"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

type Player = { player_name: string | null; player_position: string | null };

// Grupa pozycji: 0 bramkarze, 1 obrona, 2 pomoc, 3 atak, 4 pozostali.
// Obsługuje nazwy z football-data ('Goalkeeper', 'Centre-Back', 'Defensive Midfield'...)
// i skróty z api-football ('G','D','M','F') — tak samo jak aplikacja natywna.
function posGroup(pos: string | null): number {
  const p = (pos ?? "").toLowerCase().trim();
  if (p === "g" || p.includes("keeper")) return 0;
  if (p === "m" || p.includes("midfield")) return 2;
  if (p === "d" || p.includes("back") || p.includes("defen")) return 1;
  if (p === "f" || p.includes("wing") || p.includes("forward") || p.includes("offen") || p.includes("striker") || p.includes("attack")) return 3;
  return 4;
}

const GROUP_NAMES = ["BRAMKARZE", "OBRONA", "POMOC", "ATAK", "POZOSTALI"];

function sortByLine(list: Player[]): Player[] {
  return [...list].sort((a, b) => posGroup(a.player_position) - posGroup(b.player_position));
}

// Słowa-szum w nazwach klubów (matches: "Arsenal FC", squads: "Arsenal").
const NOISE = new Set([
  "fc","cf","afc","sc","sk","bc","ec","se","ca","ac","ud","rb","af","cd","fk",
  "sv","ss","as","us","ssc","ofc","cfc","clube","club","calcio","de","la","el",
]);

// Rdzeń nazwy: usuwa słowa-szum, zostawia istotne tokeny.
function coreName(name: string): string {
  return name
    .split(/\s+/)
    .filter(w => !NOISE.has(w.toLowerCase().replace(/[.]/g, "")))
    .join(" ")
    .trim();
}

// Najdłuższy istotny token (np. "Bayern" z "FC Bayern München" → trafia "Bayern Munich").
function longestToken(name: string): string {
  const tokens = coreName(name).split(/\s+/).filter(w => w.length >= 4);
  return tokens.sort((a, b) => b.length - a.length)[0] ?? "";
}

// Pobiera kadrę z dopasowaniem: dokładne → rdzeń (ilike) → najdłuższy token (ilike).
async function fetchSquad(teamName: string): Promise<Player[]> {
  const sel = "player_name, player_position";
  const exact = await supabase.from("squads").select(sel).eq("team_name", teamName);
  if ((exact.data?.length ?? 0) > 0) return exact.data as Player[];

  const core = coreName(teamName);
  if (core && core.toLowerCase() !== teamName.toLowerCase()) {
    const byCore = await supabase.from("squads").select(sel).ilike("team_name", `%${core}%`);
    if ((byCore.data?.length ?? 0) > 0) return byCore.data as Player[];
  }

  const token = longestToken(teamName);
  if (token) {
    const byTok = await supabase.from("squads").select(sel).ilike("team_name", `%${token}%`);
    if ((byTok.data?.length ?? 0) > 0) return byTok.data as Player[];
  }
  return [];
}

function Column({ squad, accent }: { squad: Player[]; accent: string }) {
  if (squad.length === 0) {
    return <p className="text-white/20 text-[11px] text-center py-3">Brak danych o kadrze</p>;
  }
  let lastGroup = -1;
  return (
    <div className="flex flex-col">
      {squad.map((p, i) => {
        const g = posGroup(p.player_position);
        const header = g !== lastGroup ? (lastGroup = g, GROUP_NAMES[g]) : null;
        return (
          <div key={i}>
            {header && (
              <p className="text-[9px] font-extrabold tracking-widest mt-2.5 mb-1" style={{ color: accent }}>{header}</p>
            )}
            <div className="flex items-start gap-1.5 py-[3px]">
              <span className="w-1.5 h-1.5 rounded-full mt-1.5 flex-shrink-0" style={{ backgroundColor: accent, opacity: 0.6 }} />
              <span className="text-white/90 text-[11px] font-medium leading-snug">{p.player_name ?? "?"}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export default function SquadsSection({ homeTeam, awayTeam }: { homeTeam: string; awayTeam: string }) {
  const [home, setHome] = useState<Player[]>([]);
  const [away, setAway] = useState<Player[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    (async () => {
      setLoading(true);
      const [h, a] = await Promise.all([fetchSquad(homeTeam), fetchSquad(awayTeam)]);
      if (!active) return;
      setHome(sortByLine(h));
      setAway(sortByLine(a));
      setLoading(false);
    })();
    return () => { active = false; };
  }, [homeTeam, awayTeam]);

  // Nic nie renderujemy dopóki ładujemy — i znikamy całkiem gdy brak składów dla obu drużyn
  if (loading) {
    return (
      <div className="px-4 mb-5">
        <div className="skeleton h-40 rounded-2xl" />
      </div>
    );
  }
  if (home.length === 0 && away.length === 0) return null;

  return (
    <div className="px-4 mb-5">
      <div className="bg-[#111] border border-white/[0.06] rounded-2xl p-4">
        <h3 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">Składy</h3>
        <div className="flex items-start">
          <div className="flex-1 min-w-0">
            <p className="text-[#F5C400] font-bold text-xs mb-1 truncate">{homeTeam}</p>
            <Column squad={home} accent="#F5C400" />
          </div>
          <div className="w-px self-stretch bg-white/[0.06] mx-3" />
          <div className="flex-1 min-w-0">
            <p className="text-blue-400 font-bold text-xs mb-1 truncate text-right">{awayTeam}</p>
            <Column squad={away} accent="#60a5fa" />
          </div>
        </div>
      </div>
    </div>
  );
}
