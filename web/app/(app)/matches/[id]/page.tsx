"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase, Match, isLive, isFinished, competitionLabel, formatMatchTime, ensureProfile } from "@/lib/supabase";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { TeamLogo } from "@/components/MatchCard";
import { calculatePoints, badgeFor } from "@/lib/scorer";
import PredictionResultOverlay from "@/components/PredictionResultOverlay";

type Prediction = {
  id: string; user_id: string; predicted_home_score: number;
  predicted_away_score: number; points_earned: number | null; is_calculated: boolean;
  profiles?: { username: string } | { username: string }[];
};

function predUsername(p: Prediction): string {
  if (!p.profiles) return "?";
  return Array.isArray(p.profiles) ? (p.profiles[0]?.username ?? "?") : p.profiles.username;
}

export default function MatchDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [match, setMatch] = useState<Match | null>(null);
  const [predictions, setPredictions] = useState<Prediction[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [username, setUsername] = useState("Ty");
  // Kontekst ligi (zamknięta grupa) — z ?league=<id>. Null = typy globalne.
  const [leagueId, setLeagueId] = useState<string | null>(null);
  const [leagueName, setLeagueName] = useState<string | null>(null);
  const [predHome, setPredHome] = useState("");
  const [predAway, setPredAway] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  const [overlay, setOverlay] = useState<null | { points: number; ph: number; pa: number; ah: number; aa: number }>(null);

  // Pokaż overlay po zakończonym, obstawionym meczu. Znacznik "potwierdzone"
  // zapisujemy dopiero po kliknięciu Sprawdź/Zamknij — dzięki temu nakładka
  // pojawia się przy każdym otwarciu aż użytkownik ją potwierdzi.
  const overlayKey = useCallback(
    (uid: string, matchId: string) => `typerly_overlay_seen_${uid}_${matchId}`,
    [],
  );

  const maybeShowOverlay = useCallback((m: Match, own: Prediction, uid: string) => {
    if (!isFinished(m.status) || m.home_score == null || m.away_score == null) return;
    if (localStorage.getItem(overlayKey(uid, m.id))) return;

    const points = own.points_earned ?? calculatePoints(
      own.predicted_home_score, own.predicted_away_score, m.home_score, m.away_score,
    );

    // Przyznaj odznakę w bazie (wygrana LUB pocieszenia) — raz na odznakę dzięki unique(user_id, badge_id)
    const badge = badgeFor(points);
    supabase.from("user_badges")
      .upsert({ user_id: uid, badge_id: badge.id, match_id: m.id }, { onConflict: "user_id,badge_id", ignoreDuplicates: true })
      .then(() => {});

    setTimeout(() => {
      setOverlay({
        points,
        ph: own.predicted_home_score, pa: own.predicted_away_score,
        ah: m.home_score!, aa: m.away_score!,
      });
    }, 600);
  }, [overlayKey]);

  // Zapamiętaj, że nakładka została potwierdzona (nie pokazuj ponownie)
  const markOverlaySeen = useCallback(() => {
    if (userId && match) localStorage.setItem(overlayKey(userId, match.id), "1");
  }, [userId, match, overlayKey]);

  useEffect(() => {
    async function load() {
      const lid = new URLSearchParams(window.location.search).get("league");
      setLeagueId(lid);

      const { data: { user } } = await supabase.auth.getUser();
      setUserId(user?.id ?? null);

      // Typy filtrowane po kontekście: w lidze tylko typy tej grupy, globalnie tylko league_id NULL
      let predQuery = supabase.from("predictions").select("*, profiles(username)").eq("match_id", id);
      predQuery = lid ? predQuery.eq("league_id", lid) : predQuery.is("league_id", null);

      const [{ data: m }, { data: preds }, { data: profile }, { data: lg }] = await Promise.all([
        supabase.from("matches").select("*").eq("id", id).single(),
        predQuery.order("points_earned", { ascending: false, nullsFirst: false }),
        user ? supabase.from("profiles").select("username").eq("id", user.id).single() : Promise.resolve({ data: null }),
        lid ? supabase.from("leagues").select("name").eq("id", lid).single() : Promise.resolve({ data: null }),
      ]);

      setMatch(m);
      setPredictions(preds ?? []);
      if ((lg as any)?.name) setLeagueName((lg as any).name);
      if ((profile as any)?.username) setUsername((profile as any).username);

      const own = (preds ?? []).find((p: Prediction) => p.user_id === user?.id);
      if (own) {
        setPredHome(String(own.predicted_home_score));
        setPredAway(String(own.predicted_away_score));
        if (m && user) maybeShowOverlay(m, own, user.id);
      }
    }
    load();
  }, [id, maybeShowOverlay]);

  async function submitPrediction() {
    if (!userId || predHome === "" || predAway === "") return;
    setSaving(true);
    setSaveError("");
    // Upewnij się, że profil istnieje (FK predictions→profiles)
    await ensureProfile();

    const h = parseInt(predHome), a = parseInt(predAway);
    // Tabela predictions nie ma constraintu (user_id, match_id, league_id) — robimy ręcznie: update albo insert.
    // Filtr po league_id zapewnia osobny typ dla każdej zamkniętej grupy.
    let existsQuery = supabase.from("predictions").select("id").eq("user_id", userId).eq("match_id", id);
    existsQuery = leagueId ? existsQuery.eq("league_id", leagueId) : existsQuery.is("league_id", null);
    const { data: existing } = await existsQuery.maybeSingle();

    // odświeżenie listy w bieżącym kontekście ligi (po zapisie lub blokadzie)
    async function refresh() {
      let q = supabase.from("predictions").select("*, profiles(username)").eq("match_id", id);
      q = leagueId ? q.eq("league_id", leagueId) : q.is("league_id", null);
      const { data } = await q.order("points_earned", { ascending: false, nullsFirst: false });
      setPredictions(data ?? []);
    }

    // Typ po zapisaniu jest zablokowany — nie pozwalamy dodać drugiego
    if (existing) {
      setSaveError("Już dodałeś typ do tego meczu — typować można tylko raz.");
      await refresh();
      setSaving(false);
      return;
    }

    const { error } = await supabase.from("predictions")
      .insert({ user_id: userId, match_id: id, predicted_home_score: h, predicted_away_score: a, league_id: leagueId });
    if (error) {
      // 23505 = naruszenie unikalności (ktoś zdążył dodać typ równolegle)
      if ((error as { code?: string }).code === "23505") {
        setSaveError("Już dodałeś typ do tego meczu — typować można tylko raz.");
      } else {
        setSaveError("Nie udało się zapisać typu: " + error.message);
      }
      await refresh();
      setSaving(false);
      return;
    }
    await refresh();
    setSaving(false);
  }

  if (!match) return (
    <div className="flex justify-center pt-20"><div className="w-8 h-8 border-2 border-[#F5C400] border-t-transparent rounded-full animate-spin" /></div>
  );

  const myPred = predictions.find(p => p.user_id === userId);
  const live = isLive(match.status);
  const finished = isFinished(match.status);
  const canPredict = !live && !finished && new Date(match.match_time) > new Date();

  return (
    <div className="flex flex-col min-h-screen pb-6 fade-in">
      {/* Header */}
      <div className="px-4 pt-6 pb-4">
        <button onClick={() => router.back()} className="text-white/40 mb-4 flex items-center gap-1 text-sm">
          <ArrowLeft size={18} /> Wróć
        </button>

        <div className="relative overflow-hidden rounded-2xl bg-[#111] border border-white/[0.06] p-5">
          <p className="text-white/30 text-[10px] font-bold uppercase tracking-widest text-center mb-4">
            {competitionLabel(match.competition, match.sport_type)}
          </p>
          <div className="flex items-center justify-between gap-3">
            <div className="flex-1 flex flex-col items-center gap-2">
              <TeamLogo url={match.home_team_logo_url} name={match.home_team_name} />
              <span className="text-white font-bold text-sm text-center leading-tight">{match.home_team_name}</span>
            </div>
            <div className="flex flex-col items-center min-w-[80px]">
              {(live || finished) && match.home_score != null ? (
                <span className="text-[#F5C400] font-black text-4xl font-archivo tabular-nums">{match.home_score}:{match.away_score}</span>
              ) : (
                <span className="text-white/20 font-black text-2xl">vs</span>
              )}
              {live && <span className="flex items-center gap-1 text-red-400 text-[10px] font-black mt-1"><span className="w-1.5 h-1.5 rounded-full bg-red-400 pulse-live" />NA ŻYWO</span>}
            </div>
            <div className="flex-1 flex flex-col items-center gap-2">
              <TeamLogo url={match.away_team_logo_url} name={match.away_team_name} />
              <span className="text-white font-bold text-sm text-center leading-tight">{match.away_team_name}</span>
            </div>
          </div>
          <p className="text-white/30 text-xs text-center mt-4">{formatMatchTime(match.match_time)}</p>
        </div>

        {leagueName && (
          <div className="mt-3 flex items-center justify-center gap-2 bg-[#F5C400]/10 border border-[#F5C400]/20 rounded-xl px-4 py-2">
            <span className="text-base">🏆</span>
            <span className="text-[#F5C400] text-xs font-bold">Typujesz w lidze: {leagueName}</span>
          </div>
        )}
      </div>

      {/* Mój typ — po zapisaniu zablokowany (nie można zmienić) */}
      {myPred ? (
        <div className="px-4 mb-5">
          <h3 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-2">Twój typ</h3>
          <div className={`rounded-xl px-4 py-3 flex items-center justify-between ${myPred.points_earned != null && myPred.points_earned > 0 ? "bg-green-500/10 border border-green-500/20" : "bg-[#111] border border-white/[0.06]"}`}>
            <span className="text-[#F5C400] font-black text-xl tabular-nums">{myPred.predicted_home_score}:{myPred.predicted_away_score}</span>
            {myPred.points_earned != null ? (
              <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${myPred.points_earned > 0 ? "bg-green-500/20 text-green-400" : "bg-white/10 text-white/40"}`}>
                +{myPred.points_earned} pkt
              </span>
            ) : (
              <span className="text-white/30 text-xs font-semibold">🔒 Typ zapisany — nie można zmienić</span>
            )}
          </div>
        </div>
      ) : canPredict ? (
        <div className="px-4 mb-5">
          <h3 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-2">Twój typ</h3>
          <div className="flex items-center gap-3 mb-3">
            <input value={predHome} onChange={e => setPredHome(e.target.value)} type="number" min="0" inputMode="numeric" placeholder="0"
              className="flex-1 min-w-0 bg-[#111] border border-white/[0.06] rounded-xl p-3 text-white text-center text-2xl font-black focus:border-[#F5C400]/40 focus:outline-none" />
            <span className="text-white/20 font-black text-xl flex-shrink-0">:</span>
            <input value={predAway} onChange={e => setPredAway(e.target.value)} type="number" min="0" inputMode="numeric" placeholder="0"
              className="flex-1 min-w-0 bg-[#111] border border-white/[0.06] rounded-xl p-3 text-white text-center text-2xl font-black focus:border-[#F5C400]/40 focus:outline-none" />
          </div>
          <button onClick={submitPrediction} disabled={saving || predHome === "" || predAway === ""}
            className="w-full bg-[#F5C400] text-black font-black py-3.5 rounded-xl disabled:opacity-50 active:scale-95 transition">
            {saving ? "Zapisywanie..." : "Zapisz typ"}
          </button>
          <p className="text-white/25 text-[11px] text-center mt-2">Po zapisaniu typu nie można go już zmienić</p>
          {saveError && <p className="text-red-400 text-sm mt-2 text-center">{saveError}</p>}
        </div>
      ) : null}

      {/* Lista typów */}
      <div className="px-4">
        <h3 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">{leagueName ? "Typy w grupie" : "Typy graczy"} ({predictions.length})</h3>
        {predictions.length === 0 ? (
          <p className="text-white/20 text-sm text-center py-8">Nikt jeszcze nie typował</p>
        ) : (
          <div className="flex flex-col gap-2">
            {predictions.map(p => (
              <div key={p.id} className={`flex items-center justify-between rounded-xl px-4 py-3 border ${p.user_id === userId ? "border-[#F5C400]/40 bg-[#F5C400]/5" : "border-white/[0.06] bg-[#111]"}`}>
                <span className="text-white font-semibold text-sm flex-1">{predUsername(p)}</span>
                <span className="text-[#F5C400] font-black mx-3">{p.predicted_home_score}:{p.predicted_away_score}</span>
                {p.points_earned != null && (
                  <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${p.points_earned > 0 ? "bg-green-500/20 text-green-400" : "bg-white/10 text-white/40"}`}>
                    +{p.points_earned}
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Overlay wyniku */}
      {overlay && (
        <PredictionResultOverlay
          username={username}
          points={overlay.points}
          predictedHome={overlay.ph}
          predictedAway={overlay.pa}
          actualHome={overlay.ah}
          actualAway={overlay.aa}
          onClose={() => { markOverlaySeen(); setOverlay(null); }}
          onCheck={() => {
            markOverlaySeen();
            setOverlay(null);
            // Tabela wyników: ranking grupy (gdy w lidze) lub ogólne statystyki w profilu
            router.push(leagueId ? `/leagues/${leagueId}` : "/profile");
          }}
        />
      )}
    </div>
  );
}
