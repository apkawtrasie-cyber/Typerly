"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState } from "react";
import { supabase, Match, isLive, isFinished } from "@/lib/supabase";
import MatchCard from "@/components/MatchCard";
import WorldCupStandings from "@/components/WorldCupStandings";
import { useLang } from "@/contexts/LangContext";
import { Locale } from "@/lib/translations";

// Mapowanie kodu języka na locale dla formatowania dat
const DATE_LOCALE: Record<Locale, string> = {
  en: "en-GB", pl: "pl-PL", de: "de-DE", fr: "fr-FR", es: "es-ES", it: "it-IT",
};

function SkeletonCard() {
  return <div className="skeleton h-28 rounded-2xl" />;
}

export default function MatchesPage() {
  const { t, locale } = useLang();
  const TABS = [
    { label: t("matches.filter_all"), key: "all" },
    { label: t("matches.upcoming"), key: "upcoming" },
    { label: "🔴 " + t("matches.live"), key: "live" },
    { label: t("matches.finished"), key: "finished" },
    { label: "🏆 " + t("matches.wc_tables"), key: "wc" },
  ];
  const [matches, setMatches] = useState<Match[]>([]);
  const [tab, setTab] = useState("upcoming");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const now = new Date();
    const from = new Date(now.getTime() - 14 * 86400000).toISOString();
    const to = new Date(now.getTime() + 60 * 86400000).toISOString();

    supabase.from("matches").select("*")
      .or("sport_type.eq.football,sport_type.is.null")
      .gte("match_time", from).lte("match_time", to)
      .order("match_time")
      .then(({ data }) => {
        const real = (data ?? []).filter(m => {
          const h = (m.home_team_name ?? "").trim().toLowerCase();
          const a = (m.away_team_name ?? "").trim().toLowerCase();
          return h && a && h !== "unknown" && a !== "unknown" && h !== "tbd" && a !== "tbd";
        });
        setMatches(real); setLoading(false);
      });
  }, []);

  const filtered = matches.filter(m => {
    if (tab === "live") return isLive(m.status);
    if (tab === "finished") return isFinished(m.status);
    if (tab === "upcoming") return !isLive(m.status) && !isFinished(m.status) && new Date(m.match_time) > new Date();
    return true;
  }).sort((a, b) => {
    if (tab === "finished") return new Date(b.match_time).getTime() - new Date(a.match_time).getTime();
    return new Date(a.match_time).getTime() - new Date(b.match_time).getTime();
  });

  // Grupowanie po dacie
  const grouped = filtered.reduce<Record<string, Match[]>>((acc, m) => {
    const key = new Date(m.match_time).toLocaleDateString(DATE_LOCALE[locale], { weekday: "long", day: "numeric", month: "long" });
    if (!acc[key]) acc[key] = [];
    acc[key].push(m);
    return acc;
  }, {});

  const liveCount = matches.filter(m => isLive(m.status)).length;

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      <h1 className="text-white font-black text-2xl font-archivo mb-4">{t("matches.title")}</h1>

      {/* Tabs */}
      <div className="flex gap-2 mb-5 overflow-x-auto scrollbar-hide -mx-4 px-4 pb-1">
        {TABS.map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={`relative flex-shrink-0 px-4 py-2 rounded-full text-xs font-black uppercase tracking-wide transition-all ${
              tab === t.key
                ? "bg-[#F5C400] text-black"
                : "bg-[#1e1e1e] border border-white/[0.12] text-white/40 hover:text-white/70"
            }`}>
            {t.label}
            {t.key === "live" && liveCount > 0 && (
              <span className="ml-1.5 bg-red-500 text-white text-[9px] font-black rounded-full px-1.5 py-0.5">{liveCount}</span>
            )}
          </button>
        ))}
      </div>

      {tab === "wc" ? (
        <WorldCupStandings />
      ) : loading ? (
        <div className="flex flex-col gap-3">{[0,1,2,3].map(i => <SkeletonCard key={i} />)}</div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="text-center py-16">
          <p className="text-4xl mb-3">⚽</p>
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
