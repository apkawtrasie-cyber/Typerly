"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase, Match, Prediction, isLive, isFinished, isUpcoming, competitionLabel, ensureProfile } from "@/lib/supabase";
import MatchCard from "@/components/MatchCard";
import { Search, ChevronRight, Zap, Clock, TrendingUp } from "lucide-react";
import Link from "next/link";
import { useLang } from "@/contexts/LangContext";

type RankingEntry = { user_id: string; username: string; total_points: number; predictions_count: number };
type PredWithMatch = Prediction & { match?: Match };

function SectionHeader({ title, icon, count, href }: { title: string; icon: React.ReactNode; count?: number; href?: string }) {
  const { t } = useLang();
  return (
    <div className="flex items-center justify-between mb-3">
      <div className="flex items-center gap-2">
        {icon}
        <h2 className="text-white font-black text-sm uppercase tracking-wider">{title}</h2>
        {count != null && <span className="text-white/30 text-xs font-semibold">({count})</span>}
      </div>
      {href && (
        <Link href={href} className="flex items-center gap-1 text-[#F5C400] text-xs font-bold">
          {t("home.see")} <ChevronRight size={14} />
        </Link>
      )}
    </div>
  );
}

function SkeletonCard() {
  return <div className="skeleton h-24 rounded-2xl" />;
}

function pointsBadge(pts: number | null) {
  if (pts === null || pts === undefined) return null;
  if (pts >= 3) return { icon: "⭐", label: `${pts} pkt`, color: "text-yellow-300", bg: "bg-yellow-400/10 border-yellow-400/20" };
  if (pts >= 1) return { icon: "🏆", label: `${pts} pkt`, color: "text-orange-300", bg: "bg-orange-400/10 border-orange-400/20" };
  return { icon: null, label: "0 pkt", color: "text-white/30", bg: "bg-white/[0.04] border-white/[0.06]" };
}

export default function HomePage() {
  const { t, locale } = useLang();
  const [username, setUsername] = useState("");
  const [totalPoints, setTotalPoints] = useState(0);
  const [liveMatches, setLiveMatches] = useState<Match[]>([]);
  const [upcoming, setUpcoming] = useState<Match[]>([]);
  const [myPredictions, setMyPredictions] = useState<Record<string, Prediction>>({});
  const [recentPreds, setRecentPreds] = useState<PredWithMatch[]>([]);
  const [ranking, setRanking] = useState<RankingEntry[]>([]);
  const [search, setSearch] = useState("");
  const [searchResults, setSearchResults] = useState<Match[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    // Upewnij się, że profil istnieje, i ustaw nick natychmiast
    const ensured = await ensureProfile();
    if (ensured) setUsername(ensured.username);

    const now = new Date();
    const from = new Date(now.getTime() - 7 * 86400000).toISOString();
    const to = new Date(now.getTime() + 60 * 86400000).toISOString();

    const [matchesRes, predsRes, profileRes, rankingRes] = await Promise.all([
      supabase.from("matches").select("*").gte("match_time", from).lte("match_time", to).order("match_time"),
      user ? supabase.from("predictions").select("*").eq("user_id", user.id) : Promise.resolve({ data: [] }),
      user ? supabase.from("profiles").select("username, total_points").eq("id", user.id).single() : Promise.resolve({ data: null }),
      supabase.from("profiles").select("id, username, total_points, predictions_count").order("total_points", { ascending: false }).limit(10),
    ]);

    const matches: Match[] = matchesRes.data ?? [];
    const preds: Prediction[] = (predsRes as any).data ?? [];
    const profile = (profileRes as any).data;
    const rankingData: RankingEntry[] = (rankingRes.data ?? []).map((r: any) => ({
      user_id: r.id, username: r.username, total_points: r.total_points ?? 0, predictions_count: r.predictions_count ?? 0,
    }));

    if (profile) {
      setUsername(profile.username ?? "");
      setTotalPoints(profile.total_points ?? 0);
    }

    const predMap: Record<string, Prediction> = {};
    let pts = 0;
    for (const p of preds) {
      predMap[p.match_id] = p;
      if (p.is_calculated) pts += p.points_earned ?? 0;
    }
    setMyPredictions(predMap);
    if (!profile) setTotalPoints(pts);

    // Ostatnie typy na zakończone mecze
    const calculated = preds.filter(p => p.is_calculated);
    if (calculated.length > 0) {
      const matchIds = calculated.map(p => p.match_id);
      const { data: mData } = await supabase.from("matches").select("*").in("id", matchIds).order("match_time", { ascending: false });
      const mMap: Record<string, Match> = {};
      for (const m of (mData ?? [])) mMap[m.id] = m;
      const enriched = calculated
        .map(p => ({ ...p, match: mMap[p.match_id] }))
        .filter(p => p.match)
        .sort((a, b) => new Date(b.match!.match_time).getTime() - new Date(a.match!.match_time).getTime());
      setRecentPreds(enriched);
    }

    const live = matches.filter(m => isLive(m.status));
    const upc = matches.filter(m => !isLive(m.status) && !isFinished(m.status) && isUpcoming(m.status) && new Date(m.match_time) > now);

    setLiveMatches(live);
    setUpcoming(upc);
    setRanking(rankingData);
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (!search.trim()) { setSearchResults([]); return; }
    const q = search.toLowerCase();
    supabase.from("matches").select("*")
      .or(`home_team_name.ilike.%${q}%,away_team_name.ilike.%${q}%`)
      .order("match_time", { ascending: false }).limit(10)
      .then(({ data }) => setSearchResults(data ?? []));
  }, [search]);

  const greetHour = new Date().getHours();
  const greeting = greetHour < 12 ? t("home.greeting_morning") : greetHour < 18 ? t("home.greeting_afternoon") : t("home.greeting_evening");
  const numLocale: Record<string, string> = { en: "en-GB", pl: "pl-PL", de: "de-DE", fr: "fr-FR", es: "es-ES", it: "it-IT" };

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-5">
        <div>
          <p className="text-white/30 text-sm">{greeting},</p>
          <h1 className="text-white font-black text-2xl font-archivo">{username || t("home.player_fallback")} 👋</h1>
        </div>
        <Link href="/profile">
          <div className="w-11 h-11 rounded-full bg-[#F5C400]/10 border border-[#F5C400]/20 flex items-center justify-center text-[#F5C400] font-black text-lg">
            {username?.[0]?.toUpperCase() ?? "?"}
          </div>
        </Link>
      </div>

      {/* Baner: Sprawdź ostatnie typy */}
      {recentPreds.length > 0 && (() => {
        const last = recentPreds[0];
        const totalCalc = recentPreds.reduce((s, p) => s + (p.points_earned ?? 0), 0);
        const hasPts = totalCalc > 0;
        return (
          <Link href="/ranking" className="block mb-6">
            <div className="relative overflow-hidden rounded-2xl px-5 py-4 flex items-center gap-4 active:scale-[0.98] transition-transform
              border border-[#F5C400]/40 bg-gradient-to-r from-[#1a1500] to-[#111]"
              style={{ boxShadow: "0 0 0 1px rgba(245,196,0,0.15), 0 0 24px rgba(245,196,0,0.15)" }}>
              {/* Pulsująca poświata */}
              <div className="absolute inset-0 rounded-2xl pointer-events-none"
                style={{ boxShadow: "inset 0 0 0 1px rgba(245,196,0,0.2)", animation: "pulse-live 2s ease-in-out infinite" }} />
              {/* Tekst */}
              <div className="flex-1 min-w-0">
                <p className="text-white/40 text-[11px] font-bold uppercase tracking-widest mb-0.5">Sprawdź ostatnie typy</p>
                <p className="text-white font-black text-base leading-tight truncate">
                  {last.match?.home_team_name} – {last.match?.away_team_name}
                </p>
                <p className="text-white/40 text-xs font-mono mt-0.5">
                  Typ: {last.predicted_home_score}:{last.predicted_away_score}
                  {last.match?.home_score != null && <> · wynik: <span className="text-white/60">{last.match.home_score}:{last.match.away_score}</span></>}
                </p>
                <p className={`text-sm font-black mt-1 ${hasPts ? "text-[#F5C400]" : "text-white/30"}`}>{totalCalc} pkt łącznie</p>
              </div>
              {/* Ikona po prawej — puchar lub gwiazdka */}
              <div className="flex-shrink-0 text-5xl leading-none">
                {hasPts ? "🏆" : "⭐"}
              </div>
            </div>
          </Link>
        );
      })()}

      {/* Wyszukiwarka */}
      <div className="relative mb-6">
        <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-white/20" />
        <input
          value={search} onChange={e => setSearch(e.target.value)}
          placeholder={t("home.search_placeholder")}
          className="w-full bg-[#111] border border-white/[0.06] rounded-2xl pl-10 pr-4 py-3 text-sm text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/30 transition"
        />
      </div>

      {/* Wyniki wyszukiwania */}
      {search && (
        <div className="mb-6">
          <SectionHeader title={t("home.results")} icon={<Search size={14} className="text-white/40" />} count={searchResults.length} />
          {searchResults.length === 0 ? (
            <p className="text-white/20 text-sm text-center py-4">{t("home.no_results")}</p>
          ) : (
            <div className="flex flex-col gap-2">
              {searchResults.map((m, i) => <MatchCard key={m.id} match={m} myPrediction={myPredictions[m.id]} index={i} />)}
            </div>
          )}
        </div>
      )}

      {!search && (
        <>
          {/* NA ŻYWO */}
          {liveMatches.length > 0 && (
            <div className="mb-6">
              <SectionHeader
                title={t("home.live")}
                icon={<Zap size={14} className="text-red-400 fill-red-400" />}
                count={liveMatches.length}
                href="/matches"
              />
              <div className="flex flex-col gap-3">
                {liveMatches.slice(0, 3).map((m, i) => <MatchCard key={m.id} match={m} myPrediction={myPredictions[m.id]} index={i} />)}
              </div>
            </div>
          )}

          {/* Nadchodzące */}
          <div className="mb-6">
            <SectionHeader
              title={liveMatches.length > 0 ? t("home.upcoming") : t("home.nearest_matches")}
              icon={<Clock size={14} className="text-[#F5C400]" />}
              count={upcoming.length}
              href="/matches"
            />
            {loading ? (
              <div className="flex flex-col gap-3">
                {[0,1,2].map(i => <SkeletonCard key={i} />)}
              </div>
            ) : upcoming.length === 0 ? (
              <p className="text-white/20 text-sm text-center py-6">{t("home.no_upcoming")}</p>
            ) : (
              <div className="flex flex-col gap-3">
                {upcoming.slice(0, 5).map((m, i) => <MatchCard key={m.id} match={m} myPrediction={myPredictions[m.id]} index={i} />)}
              </div>
            )}
          </div>

          {/* Ranking tygodnia */}
          {ranking.length > 0 && (
            <div className="mb-6">
              <SectionHeader title={t("home.week_ranking")} icon={<TrendingUp size={14} className="text-[#F5C400]" />} />
              <div className="bg-[#111] border border-white/[0.06] rounded-2xl overflow-hidden">
                {ranking.slice(0, 5).map((r, i) => (
                  <div key={r.user_id} className={`flex items-center px-4 py-3 gap-3 ${i < ranking.length - 1 ? "border-b border-white/[0.04]" : ""}`}>
                    <span className={`w-7 text-center font-black text-sm ${i === 0 ? "text-[#F5C400]" : i === 1 ? "text-white/50" : i === 2 ? "text-orange-400/70" : "text-white/20"}`}>
                      {i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : `${i + 1}.`}
                    </span>
                    <div className="flex-1">
                      <p className="text-white font-semibold text-sm">{r.username}</p>
                      <p className="text-white/30 text-[10px]">{r.predictions_count} {t("home.predictions_short")}</p>
                    </div>
                    <span className="text-[#F5C400] font-black">{r.total_points} {t("home.points")}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </>
      )}


    </div>
  );
}
