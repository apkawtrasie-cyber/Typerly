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

// Mecz "prawdziwy" = ma rozstawione drużyny. Zaślepki drabinki pucharowej
// w bazie mają nazwy "Unknown" (jeszcze nieznani rywale) — nie pokazujemy ich.
function isRealMatch(m: Match): boolean {
  const h = (m.home_team_name ?? "").trim().toLowerCase();
  const a = (m.away_team_name ?? "").trim().toLowerCase();
  return !!h && !!a && h !== "unknown" && a !== "unknown" && h !== "tbd" && a !== "tbd";
}

const SPORT_ICONS: Record<string, string> = {
  football: "⚽", "fifa world cup": "🏆", "copa libertadores": "🏆",
  basketball: "🏀", volleyball: "🏐", handball: "🤾", tennis: "🎾", hockey: "🏒",
};
// translatable sport names (keyed sport_type → translation key)
const SPORT_KEY_MAP: Record<string, "sport.football" | "sport.volleyball" | "sport.handball"> = {
  football: "sport.football", volleyball: "sport.volleyball", handball: "sport.handball",
};

// Poziom gracza wg sumy punktów — emoji + klucz tłumaczenia
function levelFor(points: number): { emoji: string; key: "level.rookie" | "level.player" | "level.expert" | "level.master" } {
  if (points >= 250) return { emoji: "👑", key: "level.master" };
  if (points >= 100) return { emoji: "⭐", key: "level.expert" };
  if (points >= 30) return { emoji: "⚡", key: "level.player" };
  return { emoji: "🌱", key: "level.rookie" };
}

function pointsBadge(pts: number | null) {
  if (pts === null || pts === undefined) return null;
  if (pts >= 3) return { icon: "⭐", label: `${pts} pkt`, color: "text-yellow-300", bg: "bg-yellow-400/10 border-yellow-400/20" };
  if (pts >= 1) return { icon: "🏆", label: `${pts} pkt`, color: "text-orange-300", bg: "bg-orange-400/10 border-orange-400/20" };
  return { icon: null, label: "0 pkt", color: "text-white/30", bg: "bg-white/[0.04] border-white/[0.12]" };
}

export default function HomePage() {
  const { t, locale } = useLang();
  const [username, setUsername] = useState("");
  const [totalPoints, setTotalPoints] = useState(0);
  const [accuracy, setAccuracy] = useState(0);
  const [streak, setStreak] = useState(0);
  const [liveMatches, setLiveMatches] = useState<Match[]>([]);
  const [upcoming, setUpcoming] = useState<Match[]>([]);
  const [myPredictions, setMyPredictions] = useState<Record<string, Prediction>>({});
  const [recentPreds, setRecentPreds] = useState<PredWithMatch[]>([]);
  const [ranking, setRanking] = useState<RankingEntry[]>([]);
  const [search, setSearch] = useState("");
  const [searchResults, setSearchResults] = useState<Match[]>([]);
  const [loading, setLoading] = useState(true);
  const [sport, setSport] = useState<string>("all");
  const [allMatches, setAllMatches] = useState<Match[]>([]);

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    // Upewnij się, że profil istnieje, i ustaw nick natychmiast
    const ensured = await ensureProfile();
    if (ensured) setUsername(ensured.username);

    const now = new Date();
    const from = new Date(now.getTime() - 7 * 86400000).toISOString();
    const to = new Date(now.getTime() + 60 * 86400000).toISOString();

    const [matchesRes, predsRes, profileRes, allProfilesRes, allPredsRes] = await Promise.all([
      supabase.from("matches").select("*").gte("match_time", from).lte("match_time", to).order("match_time"),
      user ? supabase.from("predictions").select("*").eq("user_id", user.id) : Promise.resolve({ data: [] }),
      user ? supabase.from("profiles").select("username").eq("id", user.id).single() : Promise.resolve({ data: null }),
      supabase.from("profiles").select("id, username"),
      supabase.from("predictions").select("user_id, points_earned").eq("is_calculated", true),
    ]);

    // Pomijamy mecze-zaślepki (drabinka pucharowa bez rozstawienia: "Unknown vs Unknown")
    const matches: Match[] = (matchesRes.data ?? []).filter(isRealMatch);
    const preds: Prediction[] = (predsRes as any).data ?? [];
    const profile = (profileRes as any).data;

    // Ranking liczony z predictions (profiles nie ma total_points)
    const ptsMap: Record<string, { pts: number; count: number }> = {};
    for (const p of ((allPredsRes as any).data ?? [])) {
      if (!ptsMap[p.user_id]) ptsMap[p.user_id] = { pts: 0, count: 0 };
      ptsMap[p.user_id].pts += p.points_earned ?? 0;
      ptsMap[p.user_id].count += 1;
    }
    const rankingData: RankingEntry[] = ((allProfilesRes as any).data ?? [])
      .filter((r: any) => ptsMap[r.id])
      .map((r: any) => ({
        user_id: r.id, username: r.username ?? "Gracz",
        total_points: ptsMap[r.id]?.pts ?? 0, predictions_count: ptsMap[r.id]?.count ?? 0,
      }))
      .sort((a: RankingEntry, b: RankingEntry) => b.total_points - a.total_points)
      .slice(0, 10);

    if (profile) {
      setUsername(profile.username ?? "");
    }

    const predMap: Record<string, Prediction> = {};
    let pts = 0, calculatedCount = 0, hits = 0;
    for (const p of preds) {
      predMap[p.match_id] = p;
      if (p.is_calculated) {
        pts += p.points_earned ?? 0;
        calculatedCount++;
        if ((p.points_earned ?? 0) > 0) hits++;
      }
    }
    setMyPredictions(predMap);
    setTotalPoints(pts);
    setAccuracy(calculatedCount > 0 ? Math.round((hits / calculatedCount) * 100) : 0);

    // Seria — kolejne trafienia od najnowszego typu (jak w profilu)
    const calculatedByDate = preds
      .filter(p => p.is_calculated)
      .sort((a, b) => new Date((b as any).updated_at ?? 0).getTime() - new Date((a as any).updated_at ?? 0).getTime());
    let s = 0;
    for (const p of calculatedByDate) {
      if ((p.points_earned ?? 0) > 0) s++;
      else break;
    }
    setStreak(s);

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

    setAllMatches(matches);
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

  // Pasek dyscyplin — lista budowana z meczów w bazie (skaluje się sam)
  const availableSports = [...new Set(allMatches.map(m => m.sport_type).filter(Boolean))];
  const matchSport = (m: Match) => sport === "all" || m.sport_type === sport;
  const liveFiltered = liveMatches.filter(matchSport);
  const upcomingFiltered = upcoming.filter(matchSport);

  const greetHour = new Date().getHours();
  const greeting = greetHour < 12 ? t("home.greeting_morning") : greetHour < 18 ? t("home.greeting_afternoon") : t("home.greeting_evening");
  const numLocale: Record<string, string> = { en: "en-GB", pl: "pl-PL", de: "de-DE", fr: "fr-FR", es: "es-ES", it: "it-IT" };

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      {/* Ambient glow w tle */}
      <div className="fixed inset-0 pointer-events-none z-0"
        style={{ background: "radial-gradient(ellipse 80% 40% at 50% -10%, rgba(245,196,0,0.07) 0%, transparent 70%)" }} />

      {/* Header */}
      <div className="relative flex items-start justify-between mb-5">
        <div>
          <p className="text-white/40 text-sm">{greeting},</p>
          <h1 className="text-white font-black text-2xl font-archivo">{username || t("home.player_fallback")} 👋</h1>
        </div>
        <Link href="/profile">
          <div className="w-11 h-11 rounded-full bg-[#F5C400]/10 border border-[#F5C400]/20 flex items-center justify-center text-[#F5C400] font-black text-lg">
            {username?.[0]?.toUpperCase() ?? "?"}
          </div>
        </Link>
      </div>

      {/* Pasek statystyk — spersonalizowane, pobierane z profilu. Klik → profil */}
      <Link href="/profile" className="relative block mb-6">
        <div className="grid grid-cols-3 gap-2.5 active:scale-[0.98] transition-transform">
          {/* Poziom */}
          <div className="rounded-2xl border border-white/[0.10] bg-[#1e1e1e] px-3 py-2.5 card-glow">
            <p className="text-white/35 text-[10px] font-bold uppercase tracking-wide">{t("home.level")}</p>
            <p className="text-white font-black text-sm mt-1 flex items-center gap-1 leading-tight">
              <span>{levelFor(totalPoints).emoji}</span>
              <span className="truncate">{t(levelFor(totalPoints).key)}</span>
            </p>
          </div>
          {/* Skuteczność */}
          <div className="rounded-2xl border border-white/[0.10] bg-[#1e1e1e] px-3 py-2.5 card-glow">
            <p className="text-white/35 text-[10px] font-bold uppercase tracking-wide">{t("profile.accuracy")}</p>
            <p className="text-[#F5C400] font-black text-base mt-1 leading-tight tabular-nums">{accuracy}%</p>
          </div>
          {/* Seria */}
          <div className="rounded-2xl border border-white/[0.10] bg-[#1e1e1e] px-3 py-2.5 card-glow">
            <p className="text-white/35 text-[10px] font-bold uppercase tracking-wide">{t("home.streak")}</p>
            <p className="text-white font-black text-sm mt-1 flex items-center gap-1 leading-tight">
              <span>{streak}</span>
              <span className="text-white/40 text-[11px] font-semibold truncate">{t("home.streak_hits")}</span>
              {streak > 0 && <span>🔥</span>}
            </p>
          </div>
        </div>
      </Link>

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
                <p className="text-white/40 text-[11px] font-bold uppercase tracking-widest mb-0.5">{t("home.check_recent")}</p>
                <p className="text-white font-black text-base leading-tight truncate">
                  {last.match?.home_team_name} – {last.match?.away_team_name}
                </p>
                <p className="text-white/40 text-xs font-mono mt-0.5">
                  {t("pred.pick_label")} {last.predicted_home_score}:{last.predicted_away_score}
                  {last.match?.home_score != null && <> · {t("pred.result_label")} <span className="text-white/60">{last.match.home_score}:{last.match.away_score}</span></>}
                </p>
                <p className={`text-sm font-black mt-1 ${hasPts ? "text-[#F5C400]" : "text-white/30"}`}>{totalCalc} {t("home.pts_total")}</p>
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
        <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30" />
        <input
          value={search} onChange={e => setSearch(e.target.value)}
          placeholder={t("home.search_placeholder")}
          className="w-full bg-[#1e1e1e] border border-white/[0.10] rounded-2xl pl-10 pr-4 py-3 text-sm text-white placeholder-white/25 focus:outline-none focus:border-[#F5C400]/40 transition"
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

      {/* Duże kafelki kategorii: Piłka · Siatkówka · Formuła */}
      {!search && (
        <div className="grid grid-cols-3 gap-3 mb-6">
          {[
            { href: "/matches", emoji: "⚽", label: t("sport.football"), glow: "from-[#1a2e1a] to-[#111]" },
            { href: "/volleyball", emoji: "🏐", label: t("sport.volleyball"), glow: "from-[#2e2a1a] to-[#111]" },
            { href: "/f1", emoji: "🏎️", label: t("sport.f1"), glow: "from-[#2e1a1a] to-[#111]" },
          ].map(({ href, emoji, label, glow }) => (
            <Link key={href} href={href} className="block">
              <div className={`flex flex-col items-center justify-center gap-2 rounded-2xl border border-white/[0.10] bg-gradient-to-b ${glow} py-5 active:scale-[0.96] transition-transform card-glow`}>
                <span className="text-4xl leading-none">{emoji}</span>
                <p className="text-white font-black text-xs uppercase tracking-wide text-center leading-tight">{label}</p>
              </div>
            </Link>
          ))}
        </div>
      )}

      {/* Pasek dyscyplin — pojawia się tylko gdy jest więcej niż jeden sport */}
      {!search && availableSports.length > 1 && (
        <div className="flex gap-2 mb-6 overflow-x-auto scrollbar-hide -mx-4 px-4 pb-1">
          <button onClick={() => setSport("all")}
            className={`flex-shrink-0 px-4 py-2 rounded-full text-xs font-black uppercase tracking-wide transition-all ${
              sport === "all" ? "bg-[#F5C400] text-black" : "bg-[#1e1e1e] border border-white/[0.12] text-white/40"
            }`}>
            {t("sport.all")}
          </button>
          {availableSports.map(s => {
            const key = s.toLowerCase();
            const icon = SPORT_ICONS[key] ?? "🏆";
            const tKey = SPORT_KEY_MAP[key];
            const label = tKey ? t(tKey) : s.charAt(0).toUpperCase() + s.slice(1);
            return (
              <button key={s} onClick={() => setSport(s)}
                className={`flex-shrink-0 px-4 py-2 rounded-full text-xs font-black uppercase tracking-wide transition-all ${
                  sport === s ? "bg-[#F5C400] text-black" : "bg-[#1e1e1e] border border-white/[0.12] text-white/40"
                }`}>
                {icon} {label}
              </button>
            );
          })}
        </div>
      )}

      {!search && (
        <>
          {/* NA ŻYWO */}
          {liveFiltered.length > 0 && (
            <div className="mb-6">
              <SectionHeader
                title={t("home.live")}
                icon={<Zap size={14} className="text-red-400 fill-red-400" />}
                count={liveFiltered.length}
                href="/matches"
              />
              <div className="flex flex-col gap-3">
                {liveFiltered.slice(0, 3).map((m, i) => <MatchCard key={m.id} match={m} myPrediction={myPredictions[m.id]} index={i} />)}
              </div>
            </div>
          )}

          {/* Nadchodzące */}
          <div className="mb-6">
            <SectionHeader
              title={liveFiltered.length > 0 ? t("home.upcoming") : t("home.nearest_matches")}
              icon={<Clock size={14} className="text-[#F5C400]" />}
              count={upcomingFiltered.length}
              href="/matches"
            />
            {loading ? (
              <div className="flex flex-col gap-3">
                {[0,1,2].map(i => <SkeletonCard key={i} />)}
              </div>
            ) : upcomingFiltered.length === 0 ? (
              <p className="text-white/20 text-sm text-center py-6">{t("home.no_upcoming")}</p>
            ) : (
              <div className="flex flex-col gap-3">
                {upcomingFiltered.slice(0, 5).map((m, i) => <MatchCard key={m.id} match={m} myPrediction={myPredictions[m.id]} index={i} />)}
              </div>
            )}
          </div>

          {/* Ranking tygodnia */}
          {ranking.length > 0 && (
            <div className="mb-6">
              <SectionHeader title={t("home.week_ranking")} icon={<TrendingUp size={14} className="text-[#F5C400]" />} />
              <div className="bg-[#1e1e1e] border border-white/[0.10] rounded-2xl overflow-hidden card-glow">
                {ranking.slice(0, 5).map((r, i) => (
                  <div key={r.user_id} className={`flex items-center px-4 py-3 gap-3 ${i < ranking.length - 1 ? "border-b border-white/[0.12]" : ""}`}>
                    <span className={`w-7 text-center font-black text-sm ${i === 0 ? "text-[#F5C400]" : i === 1 ? "text-white/60" : i === 2 ? "text-orange-400/80" : "text-white/30"}`}>
                      {i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : `${i + 1}.`}
                    </span>
                    <div className="flex-1">
                      <p className="text-white font-semibold text-sm">{r.username}</p>
                      <p className="text-white/40 text-[10px]">{r.predictions_count} {t("home.predictions_short")}</p>
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
