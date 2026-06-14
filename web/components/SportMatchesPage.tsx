"use client";
import { useEffect, useState } from "react";
import { Info, ArrowLeft } from "lucide-react";
import { useRouter } from "next/navigation";
import { supabase, Match, isLive, isFinished } from "@/lib/supabase";
import MatchCard from "@/components/MatchCard";
import SportInfoModal from "@/components/SportInfoModal";
import { useLang } from "@/contexts/LangContext";
import type { TranslationKey } from "@/lib/translations";

function SkeletonCard() {
  return <div className="skeleton h-28 rounded-2xl" />;
}

const TABS: { labelKey: TranslationKey; key: string; emoji?: string }[] = [
  { labelKey: "matches.upcoming", key: "upcoming" },
  { labelKey: "matches.live", key: "live", emoji: "🔴" },
  { labelKey: "matches.finished", key: "finished" },
  { labelKey: "matches.standings", key: "standings" },
];

// Oblicza tabelę ligową z wyników meczów (W/D/L + bramki/sety)
type StandingRow = {
  team: string;
  played: number;
  won: number;
  draw: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
  points: number;
};

function computeStandings(matches: Match[], isVolleyball: boolean): Record<string, StandingRow[]> {
  const finished = matches.filter(m => isFinished(m.status) && m.home_score != null && m.away_score != null);
  const byComp: Record<string, Record<string, StandingRow>> = {};

  for (const m of finished) {
    const comp = m.competition ?? "Inne";
    if (!byComp[comp]) byComp[comp] = {};
    const rows = byComp[comp];
    const hs = Number(m.home_score);
    const as_ = Number(m.away_score);

    for (const [team, gf, ga] of [[m.home_team_name, hs, as_], [m.away_team_name, as_, hs]] as [string, number, number][]) {
      if (!rows[team]) rows[team] = { team, played: 0, won: 0, draw: 0, lost: 0, goalsFor: 0, goalsAgainst: 0, points: 0 };
      const r = rows[team];
      r.played++;
      r.goalsFor += gf;
      r.goalsAgainst += ga;
      if (gf > ga) { r.won++; r.points += isVolleyball ? (ga >= 2 ? 2 : 3) : 3; }
      else if (gf < ga) { r.lost++; if (isVolleyball && gf >= 2) r.points += 1; }
      else { r.draw++; r.points += 1; }
    }
  }

  const result: Record<string, StandingRow[]> = {};
  for (const [comp, rows] of Object.entries(byComp)) {
    result[comp] = Object.values(rows).sort((a, b) => b.points - a.points || (b.goalsFor - b.goalsAgainst) - (a.goalsFor - a.goalsAgainst));
  }
  return result;
}

function StandingsSection({ matches, sportType, t }: { matches: Match[]; sportType: string; t: (k: TranslationKey) => string }) {
  const isVolleyball = sportType === "volleyball";
  const tables = computeStandings(matches, isVolleyball);
  const comps = Object.keys(tables);

  if (comps.length === 0) {
    return (
      <div className="text-center py-16">
        <p className="text-4xl mb-3">{isVolleyball ? "🏐" : "🤾"}</p>
        <p className="text-white/30 font-semibold">{t("matches.no_standings")}</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      {comps.map(comp => (
        <div key={comp}>
          <p className="text-white/40 text-[11px] font-black uppercase tracking-widest mb-2">{comp}</p>
          <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl overflow-hidden">
            <div className="flex items-center px-3 py-2 text-white/30 text-[10px] font-bold uppercase border-b border-white/[0.04]">
              <span className="w-6 text-center">#</span>
              <span className="flex-1 pl-1">{t("wc.team")}</span>
              <span className="w-6 text-center">{t("wc.col_played")}</span>
              <span className="w-6 text-center">{t("wc.col_won")}</span>
              <span className="w-6 text-center">{t("wc.col_draw")}</span>
              <span className="w-6 text-center">{t("wc.col_lost")}</span>
              <span className="w-9 text-center">+/-</span>
              <span className="w-8 text-center text-[#F5C400]">{t("wc.col_pts")}</span>
            </div>
            {tables[comp].map((r, i) => {
              const diff = r.goalsFor - r.goalsAgainst;
              return (
                <div key={r.team} className={`flex items-center px-3 py-2.5 ${i < tables[comp].length - 1 ? "border-b border-white/[0.03]" : ""}`}>
                  <span className={`w-6 text-center font-black text-sm ${i === 0 ? "text-[#F5C400]" : i < 3 ? "text-white/40" : "text-white/20"}`}>{i + 1}</span>
                  <span className="flex-1 text-white font-semibold text-xs truncate pl-1">{r.team}</span>
                  <span className="w-6 text-center text-white/60 text-xs tabular-nums">{r.played}</span>
                  <span className="w-6 text-center text-white/40 text-xs tabular-nums">{r.won}</span>
                  <span className="w-6 text-center text-white/40 text-xs tabular-nums">{r.draw}</span>
                  <span className="w-6 text-center text-white/40 text-xs tabular-nums">{r.lost}</span>
                  <span className={`w-9 text-center text-xs tabular-nums font-semibold ${diff > 0 ? "text-green-400/70" : diff < 0 ? "text-red-400/70" : "text-white/40"}`}>
                    {diff > 0 ? "+" : ""}{diff}
                  </span>
                  <span className="w-8 text-center text-[#F5C400] font-black text-sm tabular-nums">{r.points}</span>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

interface Props {
  sportType: string;
  title: string;
  emoji: string;
}

export default function SportMatchesPage({ sportType, title, emoji }: Props) {
  const router = useRouter();
  const { t, locale } = useLang();
  const [matches, setMatches] = useState<Match[]>([]);
  const [tab, setTab] = useState("upcoming");
  const [loading, setLoading] = useState(true);
  const [showInfo, setShowInfo] = useState(false);

  useEffect(() => {
    const now = new Date();
    const from = new Date(now.getTime() - 30 * 86400000).toISOString();
    const to = new Date(now.getTime() + 60 * 86400000).toISOString();

    supabase.from("matches").select("*")
      .eq("sport_type", sportType)
      .gte("match_time", from).lte("match_time", to)
      .order("match_time")
      .then(({ data }) => {
        setMatches(data ?? []);
        setLoading(false);
      });
  }, [sportType]);

  const filtered = matches.filter(m => {
    if (tab === "live") return isLive(m.status);
    if (tab === "finished") return isFinished(m.status);
    return !isLive(m.status) && !isFinished(m.status) && new Date(m.match_time) > new Date();
  }).sort((a, b) => {
    if (tab === "finished") return new Date(b.match_time).getTime() - new Date(a.match_time).getTime();
    return new Date(a.match_time).getTime() - new Date(b.match_time).getTime();
  });

  const grouped = filtered.reduce<Record<string, Match[]>>((acc, m) => {
    const key = new Date(m.match_time).toLocaleDateString(locale, { weekday: "long", day: "numeric", month: "long" });
    if (!acc[key]) acc[key] = [];
    acc[key].push(m);
    return acc;
  }, {});

  const liveCount = matches.filter(m => isLive(m.status)).length;

  // Tytuł z tłumaczeń wg dyscypliny; gdy brak klucza — użyj przekazanego title
  const sportTitle = sportType === "volleyball" ? t("sport.volleyball")
    : sportType === "handball" ? t("sport.handball")
    : title;

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      <div className="flex items-center gap-3 mb-5">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.06] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <h1 className="text-white font-black text-2xl font-archivo flex-1">{emoji} {sportTitle}</h1>
        <button onClick={() => setShowInfo(true)} className="w-9 h-9 rounded-full bg-white/[0.06] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <Info size={18} className="text-white/40" />
        </button>
      </div>
      {showInfo && <SportInfoModal sport={sportType} onClose={() => setShowInfo(false)} />}

      <div className="flex gap-2 mb-5 overflow-x-auto scrollbar-hide -mx-4 px-4 pb-1">
        {TABS.map(tabItem => (
          <button key={tabItem.key} onClick={() => setTab(tabItem.key)}
            className={`relative flex-shrink-0 px-4 py-2 rounded-full text-xs font-black uppercase tracking-wide transition-all ${
              tab === tabItem.key
                ? "bg-[#F5C400] text-black"
                : "bg-[#1e1e1e] border border-white/[0.12] text-white/50 hover:text-white/70"
            }`}>
            {tabItem.emoji ? `${tabItem.emoji} ` : ""}{t(tabItem.labelKey)}
            {tabItem.key === "live" && liveCount > 0 && (
              <span className="ml-1.5 bg-red-500 text-white text-[9px] font-black rounded-full px-1.5 py-0.5">{liveCount}</span>
            )}
          </button>
        ))}
      </div>

      {tab === "standings" ? (
        loading
          ? <div className="flex flex-col gap-2">{[0,1,2].map(i => <div key={i} className="skeleton h-40 rounded-2xl" />)}</div>
          : <StandingsSection matches={matches} sportType={sportType} t={t} />
      ) : loading ? (
        <div className="flex flex-col gap-3">{[0,1,2,3].map(i => <SkeletonCard key={i} />)}</div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="text-center py-16">
          <p className="text-4xl mb-3">{emoji}</p>
          <p className="text-white/30 font-semibold">{t("matches.no_in_category")}</p>
        </div>
      ) : (
        <div className="flex flex-col gap-6">
          {Object.entries(grouped).map(([date, dayMatches]) => (
            <div key={date}>
              <p className="text-white/25 text-[11px] font-bold uppercase tracking-widest mb-2 capitalize">{date}</p>
              <div className="flex flex-col gap-2">
                {dayMatches.map((m, i) => <MatchCard key={m.id} match={m} index={i} />)}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
