"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState } from "react";
import { supabase, Match, isLive, isFinished } from "@/lib/supabase";
import MatchCard from "@/components/MatchCard";
import WorldCupStandings from "@/components/WorldCupStandings";
import { useLang } from "@/contexts/LangContext";
import { Locale, TranslationKey } from "@/lib/translations";
import { Search, ArrowLeft, ChevronRight } from "lucide-react";
import Link from "next/link";

// Mapowanie kodu języka na locale dla formatowania dat
const DATE_LOCALE: Record<Locale, string> = {
  en: "en-GB", pl: "pl-PL", de: "de-DE", fr: "fr-FR", es: "es-ES", it: "it-IT",
};

// Przyjazne nazwy rozgrywek + flaga/emoji — żeby gracz wiedział co obstawia
const FOOTBALL_COMPS: Record<string, { name: string; flag: string }> = {
  WC:  { name: "Mistrzostwa Świata", flag: "🏆" },
  EC:  { name: "Mistrzostwa Europy", flag: "🏆" },
  CL:  { name: "Liga Mistrzów", flag: "⭐" },
  CLI: { name: "Copa Libertadores", flag: "🏆" },
  PL:  { name: "Premier League", flag: "🏴" },
  ELC: { name: "Championship (Anglia)", flag: "🏴" },
  PD:  { name: "La Liga (Hiszpania)", flag: "🇪🇸" },
  SA:  { name: "Serie A (Włochy)", flag: "🇮🇹" },
  BL1: { name: "Bundesliga (Niemcy)", flag: "🇩🇪" },
  FL1: { name: "Ligue 1 (Francja)", flag: "🇫🇷" },
  DED: { name: "Eredivisie (Holandia)", flag: "🇳🇱" },
  PPL: { name: "Primeira Liga (Portugalia)", flag: "🇵🇹" },
  BSA: { name: "Brasileirão (Brazylia)", flag: "🇧🇷" },
};
// Turnieje na górze listy, reszta wg liczby meczów
const COMP_PRIORITY = ["WC", "EC", "CL", "CLI"];

function compMeta(code: string) {
  return FOOTBALL_COMPS[code] ?? { name: code, flag: "⚽" };
}

function SkeletonCard() {
  return <div className="skeleton h-28 rounded-2xl" />;
}

// Tabela ligowa liczona z zakończonych meczów (3 pkt zwycięstwo, 1 remis)
type TableRow = { team: string; p: number; w: number; d: number; l: number; gf: number; ga: number; pts: number };
function leagueTable(ms: Match[]): TableRow[] {
  const finished = ms.filter(m => isFinished(m.status) && m.home_score != null && m.away_score != null);
  const map: Record<string, TableRow> = {};
  for (const m of finished) {
    const hs = Number(m.home_score), as_ = Number(m.away_score);
    for (const [team, gf, ga] of [[m.home_team_name, hs, as_], [m.away_team_name, as_, hs]] as [string, number, number][]) {
      if (!map[team]) map[team] = { team, p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0, pts: 0 };
      const r = map[team];
      r.p++; r.gf += gf; r.ga += ga;
      if (gf > ga) { r.w++; r.pts += 3; }
      else if (gf < ga) { r.l++; }
      else { r.d++; r.pts += 1; }
    }
  }
  return Object.values(map).sort((a, b) => b.pts - a.pts || (b.gf - b.ga) - (a.gf - a.ga) || b.gf - a.gf);
}

function FootballStandings({ matches, t }: { matches: Match[]; t: (k: TranslationKey) => string }) {
  const rows = leagueTable(matches);
  if (rows.length === 0) {
    return (
      <div className="text-center py-16">
        <p className="text-4xl mb-3">⚽</p>
        <p className="text-white/30 font-semibold">{t("matches.no_standings")}</p>
      </div>
    );
  }
  return (
    <div className="bg-[#1e1e1e] border border-white/[0.10] rounded-2xl overflow-hidden card-glow">
      <div className="flex items-center px-3 py-2 text-white/30 text-[10px] font-bold uppercase border-b border-white/[0.06]">
        <span className="w-6 text-center">#</span>
        <span className="flex-1 pl-1">{t("wc.team")}</span>
        <span className="w-7 text-center">{t("wc.col_played")}</span>
        <span className="w-9 text-center">+/-</span>
        <span className="w-9 text-center text-[#F5C400]">{t("wc.col_pts")}</span>
      </div>
      {rows.map((r, i) => (
        <div key={r.team} className={`flex items-center px-3 py-2.5 ${i < rows.length - 1 ? "border-b border-white/[0.04]" : ""}`}>
          <span className={`w-6 text-center font-black text-sm ${i < 4 ? "text-[#F5C400]" : i >= rows.length - 3 ? "text-red-400/60" : "text-white/30"}`}>{i + 1}</span>
          <span className="flex-1 pl-1 text-white text-sm font-semibold truncate">{r.team}</span>
          <span className="w-7 text-center text-white/50 text-sm tabular-nums">{r.p}</span>
          <span className="w-9 text-center text-white/50 text-sm tabular-nums">{r.gf - r.ga > 0 ? "+" : ""}{r.gf - r.ga}</span>
          <span className="w-9 text-center text-[#F5C400] font-black text-sm tabular-nums">{r.pts}</span>
        </div>
      ))}
    </div>
  );
}

export default function MatchesPage() {
  const { t, locale } = useLang();
  const [matches, setMatches] = useState<Match[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedComp, setSelectedComp] = useState<string | null>(null);
  const [tab, setTab] = useState("upcoming");
  const [search, setSearch] = useState("");

  useEffect(() => {
    const now = new Date();
    const from = new Date(now.getTime() - 30 * 86400000).toISOString();
    const to = new Date(now.getTime() + 180 * 86400000).toISOString();

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

  const now = new Date();

  // ─── Lista rozgrywek (hub) ─────────────────────────────────────────────────
  const compStats: Record<string, { upcoming: number; total: number }> = {};
  for (const m of matches) {
    const c = m.competition ?? "OTHER";
    if (!compStats[c]) compStats[c] = { upcoming: 0, total: 0 };
    compStats[c].total++;
    if (isLive(m.status) || (!isFinished(m.status) && new Date(m.match_time) >= now)) {
      compStats[c].upcoming++;
    }
  }
  const competitions = Object.keys(compStats).sort((a, b) => {
    const pa = COMP_PRIORITY.indexOf(a), pb = COMP_PRIORITY.indexOf(b);
    if (pa !== -1 || pb !== -1) {
      if (pa === -1) return 1;
      if (pb === -1) return -1;
      return pa - pb;
    }
    // potem wg liczby nadchodzących, malejąco
    return compStats[b].upcoming - compStats[a].upcoming;
  });

  // ─── Mecze wybranej rozgrywki ──────────────────────────────────────────────
  const q = search.trim().toLowerCase();
  const filtered = matches.filter(m => {
    if ((m.competition ?? "OTHER") !== selectedComp) return false;
    if (q) {
      const h = (m.home_team_name ?? "").toLowerCase();
      const a = (m.away_team_name ?? "").toLowerCase();
      if (!h.includes(q) && !a.includes(q)) return false;
    }
    if (tab === "live") return isLive(m.status);
    if (tab === "finished") return isFinished(m.status);
    if (tab === "upcoming") return !isLive(m.status) && !isFinished(m.status) && new Date(m.match_time) > now;
    return true;
  }).sort((a, b) => {
    if (tab === "finished") return new Date(b.match_time).getTime() - new Date(a.match_time).getTime();
    return new Date(a.match_time).getTime() - new Date(b.match_time).getTime();
  });

  const grouped = filtered.reduce<Record<string, Match[]>>((acc, m) => {
    const key = new Date(m.match_time).toLocaleDateString(DATE_LOCALE[locale], { weekday: "long", day: "numeric", month: "long" });
    if (!acc[key]) acc[key] = [];
    acc[key].push(m);
    return acc;
  }, {});

  const compMatches = selectedComp ? matches.filter(m => (m.competition ?? "OTHER") === selectedComp) : [];
  const liveCount = compMatches.filter(m => isLive(m.status)).length;

  const SUB_TABS: { label: string; key: string }[] = [
    { label: t("matches.upcoming"), key: "upcoming" },
    { label: "🔴 " + t("matches.live"), key: "live" },
    { label: t("matches.finished"), key: "finished" },
    { label: "🏆 " + t("matches.standings"), key: "table" },
  ];

  // ════════════════════════════════════════════════════════════════════════
  // WIDOK 1: HUB — przełącznik sportu + kafelki rozgrywek
  // ════════════════════════════════════════════════════════════════════════
  if (!selectedComp) {
    const sportTiles: { href: string; emoji: string; labelKey: TranslationKey; active?: boolean }[] = [
      { href: "/matches", emoji: "⚽", labelKey: "sport.football", active: true },
      { href: "/volleyball", emoji: "🏐", labelKey: "sport.volleyball" },
      { href: "/handball", emoji: "🤾", labelKey: "sport.handball" },
      { href: "/f1", emoji: "🏎️", labelKey: "sport.f1" },
    ];

    return (
      <div className="px-4 pt-6 pb-6 fade-in">
        <h1 className="text-white font-black text-2xl font-archivo mb-4">{t("matches.title")}</h1>

        {/* Przełącznik sportu */}
        <div className="flex gap-3 mb-6 overflow-x-auto scrollbar-hide -mx-4 px-4 pb-1">
          {sportTiles.map(({ href, emoji, labelKey, active }) => (
            <Link key={href} href={href} className="flex-shrink-0 w-24">
              <div className={`flex flex-col items-center justify-center gap-1.5 rounded-2xl border py-4 transition-transform active:scale-[0.96] ${
                active ? "border-[#F5C400]/50 bg-[#F5C400]/[0.08]" : "border-white/[0.10] bg-[#1e1e1e]"
              }`}>
                <span className="text-3xl leading-none">{emoji}</span>
                <p className={`font-black text-[11px] uppercase tracking-wide text-center leading-tight ${active ? "text-[#F5C400]" : "text-white/70"}`}>
                  {t(labelKey)}
                </p>
              </div>
            </Link>
          ))}
        </div>

        {/* Kafelki rozgrywek */}
        <p className="text-white/25 text-[11px] font-bold uppercase tracking-widest mb-3">{t("matches.competitions")}</p>
        {loading ? (
          <div className="flex flex-col gap-2">{[0,1,2,3,4].map(i => <SkeletonCard key={i} />)}</div>
        ) : competitions.length === 0 ? (
          <div className="text-center py-16">
            <p className="text-4xl mb-3">⚽</p>
            <p className="text-white/30 font-semibold">{t("matches.no_in_category")}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {competitions.map(code => {
              const meta = compMeta(code);
              const st = compStats[code];
              return (
                <button key={code} onClick={() => { setSelectedComp(code); setTab(st.upcoming > 0 ? "upcoming" : "finished"); }}
                  className="flex items-center gap-3 rounded-2xl border border-white/[0.10] bg-[#1e1e1e] px-4 py-3.5 text-left active:scale-[0.98] transition card-glow">
                  <span className="text-3xl leading-none flex-shrink-0">{meta.flag}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-white font-black text-sm truncate">{meta.name}</p>
                    <p className="text-white/35 text-[11px] font-semibold">
                      {st.upcoming > 0
                        ? `${st.upcoming} ${t("matches.matches_count")}`
                        : t("matches.ended")}
                    </p>
                  </div>
                  <ChevronRight size={18} className="text-white/25 flex-shrink-0" />
                </button>
              );
            })}
          </div>
        )}
      </div>
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // WIDOK 2: ROZGRYWKI — lista meczów wybranej ligi (z powrotem do huba)
  // ════════════════════════════════════════════════════════════════════════
  const meta = compMeta(selectedComp);
  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      <div className="flex items-center gap-3 mb-4">
        <button onClick={() => { setSelectedComp(null); setSearch(""); }}
          className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <h1 className="text-white font-black text-xl font-archivo flex items-center gap-2">
          <span>{meta.flag}</span><span className="truncate">{meta.name}</span>
        </h1>
      </div>

      {/* Wyszukiwarka */}
      <div className="relative mb-4">
        <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30" />
        <input
          value={search} onChange={e => setSearch(e.target.value)}
          placeholder={t("home.search_placeholder")}
          className="w-full bg-[#1e1e1e] border border-white/[0.10] rounded-2xl pl-10 pr-4 py-3 text-sm text-white placeholder-white/25 focus:outline-none focus:border-[#F5C400]/40 transition"
        />
      </div>

      {/* Zakładki */}
      <div className="flex gap-2 mb-5 overflow-x-auto scrollbar-hide -mx-4 px-4 pb-1">
        {SUB_TABS.map(st => (
          <button key={st.key} onClick={() => setTab(st.key)}
            className={`relative flex-shrink-0 px-4 py-2 rounded-full text-xs font-black uppercase tracking-wide transition-all ${
              tab === st.key ? "bg-[#F5C400] text-black" : "bg-[#1e1e1e] border border-white/[0.12] text-white/40 hover:text-white/70"
            }`}>
            {st.label}
            {st.key === "live" && liveCount > 0 && (
              <span className="ml-1.5 bg-red-500 text-white text-[9px] font-black rounded-full px-1.5 py-0.5">{liveCount}</span>
            )}
          </button>
        ))}
      </div>

      {tab === "table" ? (
        selectedComp === "WC" ? <WorldCupStandings /> : <FootballStandings matches={compMatches} t={t} />
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
