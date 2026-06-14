"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase";
import confetti from "canvas-confetti";
import { ArrowLeft, Trophy, Star, Crown } from "lucide-react";
import { useRouter } from "next/navigation";
import Link from "next/link";

type GlobalEntry = { user_id: string; username: string; total_points: number; predictions_count: number };
type PredSummary = { points_earned: number; match_home: string; match_away: string; predicted_h: number; predicted_a: number; real_h: number | null; real_a: number | null; match_time: string | null };

function medal(pos: number) {
  if (pos === 0) return "🥇";
  if (pos === 1) return "🥈";
  if (pos === 2) return "🥉";
  return null;
}

function pointIcon(pts: number) {
  if (pts >= 3) return { icon: "⭐", color: "text-yellow-300", label: `${pts} pkt` };
  if (pts >= 1) return { icon: "🏆", color: "text-orange-300", label: `${pts} pkt` };
  return { icon: null, color: "text-white/30", label: "0 pkt" };
}

export default function RankingPage() {
  const router = useRouter();
  const [ranking, setRanking] = useState<GlobalEntry[]>([]);
  const [myId, setMyId] = useState<string | null>(null);
  const [myPreds, setMyPreds] = useState<PredSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"global" | "moje">("global");

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    setMyId(user?.id ?? null);

    const [rankRes, predRes] = await Promise.all([
      supabase.from("profiles")
        .select("id, username, total_points, predictions_count")
        .order("total_points", { ascending: false })
        .limit(50),
      user ? supabase.from("predictions")
        .select("points_earned, predicted_home_score, predicted_away_score, is_calculated, matches(home_team_name, away_team_name, home_score, away_score, match_time)")
        .eq("user_id", user.id)
        .eq("is_calculated", true)
        .order("created_at", { ascending: false })
        .limit(30) : Promise.resolve({ data: [] }),
    ]);

    const entries: GlobalEntry[] = (rankRes.data ?? []).map((r: any) => ({
      user_id: r.id, username: r.username, total_points: r.total_points ?? 0, predictions_count: r.predictions_count ?? 0,
    }));
    setRanking(entries);

    const preds: PredSummary[] = ((predRes as any).data ?? []).map((p: any) => ({
      points_earned: p.points_earned ?? 0,
      match_home: p.matches?.home_team_name ?? "",
      match_away: p.matches?.away_team_name ?? "",
      predicted_h: p.predicted_home_score,
      predicted_a: p.predicted_away_score,
      real_h: p.matches?.home_score ?? null,
      real_a: p.matches?.away_score ?? null,
      match_time: p.matches?.match_time ?? null,
    }));
    setMyPreds(preds);
    setLoading(false);

    // Konfetti po załadowaniu
    if (user) {
      const myEntry = entries.find(e => e.user_id === user.id);
      const hasPts = (myEntry?.total_points ?? 0) > 0;
      setTimeout(() => {
        if (hasPts) {
          confetti({ particleCount: 100, spread: 80, origin: { y: 0.3 }, colors: ["#F5C400", "#fff", "#FFD700", "#FF9800"] });
        } else {
          confetti({ particleCount: 25, spread: 40, origin: { y: 0.3 }, colors: ["#ffffff22", "#888"] });
        }
      }, 400);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const myPosition = ranking.findIndex(e => e.user_id === myId);
  const myEntry = myPosition >= 0 ? ranking[myPosition] : null;

  return (
    <div className="px-4 pt-6 pb-nav fade-in">
      {/* Header */}
      <div className="flex items-center gap-3 mb-5">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.06] flex items-center justify-center">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <h1 className="text-white font-black text-2xl font-archivo flex-1">Ranking</h1>
        {myEntry && (
          <div className="bg-[#F5C400]/10 border border-[#F5C400]/30 rounded-xl px-3 py-1.5 text-right">
            <p className="text-[#F5C400] font-black text-sm">#{myPosition + 1}</p>
            <p className="text-white/40 text-[10px]">{myEntry.total_points} pkt</p>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="flex bg-[#111] border border-white/[0.06] rounded-2xl p-1 mb-5">
        {(["global", "moje"] as const).map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`flex-1 py-2 rounded-xl text-sm font-black transition ${tab === t ? "bg-[#F5C400] text-black" : "text-white/40"}`}>
            {t === "global" ? "🌍 Globalny" : "📋 Moje typy"}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex flex-col gap-2">
          {[0,1,2,3,4].map(i => <div key={i} className="skeleton h-16 rounded-2xl" />)}
        </div>
      ) : tab === "global" ? (
        <>
          {/* Podium top 3 */}
          {ranking.length >= 3 && (
            <div className="flex items-end justify-center gap-2 mb-6">
              {[ranking[1], ranking[0], ranking[2]].map((r, vi) => {
                const realPos = vi === 0 ? 1 : vi === 1 ? 0 : 2;
                const heights = ["h-20", "h-28", "h-16"];
                const isMe = r.user_id === myId;
                return (
                  <div key={r.user_id} className="flex-1 flex flex-col items-center gap-1">
                    <p className="text-lg">{medal(realPos)}</p>
                    <div className={`w-full ${heights[vi]} rounded-t-2xl flex flex-col items-center justify-end pb-2 border-t border-x
                      ${realPos === 0 ? "bg-[#F5C400]/10 border-[#F5C400]/30" : "bg-white/[0.04] border-white/[0.06]"}
                      ${isMe ? "ring-2 ring-[#F5C400]/40" : ""}`}>
                      <p className={`font-black text-xs truncate px-1 text-center ${realPos === 0 ? "text-[#F5C400]" : "text-white/70"}`}>{r.username}</p>
                      <p className={`font-black text-sm ${realPos === 0 ? "text-[#F5C400]" : "text-white/40"}`}>{r.total_points}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Lista */}
          <div className="bg-[#111] border border-white/[0.06] rounded-2xl overflow-hidden">
            {ranking.map((r, i) => {
              const isMe = r.user_id === myId;
              const m = medal(i);
              return (
                <div key={r.user_id}
                  className={`flex items-center px-4 py-3 gap-3 ${i < ranking.length - 1 ? "border-b border-white/[0.04]" : ""}
                    ${isMe ? "bg-[#F5C400]/[0.06]" : ""}`}>
                  <span className="w-7 text-center font-black text-sm text-white/20">
                    {m ?? `${i + 1}.`}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5">
                      <p className={`font-bold text-sm ${isMe ? "text-[#F5C400]" : "text-white"} truncate`}>{r.username}</p>
                      {isMe && <Crown size={11} className="text-[#F5C400] flex-shrink-0" />}
                    </div>
                    <p className="text-white/30 text-[10px]">{r.predictions_count} typów</p>
                  </div>
                  <span className={`font-black text-sm ${isMe ? "text-[#F5C400]" : "text-white/70"}`}>{r.total_points} pkt</span>
                </div>
              );
            })}
          </div>
        </>
      ) : (
        /* Moje typy */
        myPreds.length === 0 ? (
          <div className="text-center py-16">
            <p className="text-5xl mb-3">🎯</p>
            <p className="text-white/40 font-bold">Brak zakończonych typów</p>
            <Link href="/matches" className="inline-block mt-4 bg-[#F5C400] text-black font-black px-6 py-3 rounded-xl">
              Obstaw mecze
            </Link>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {myPreds.map((p, i) => {
              const started = p.match_time ? new Date(p.match_time) <= new Date() : true;
              const pi = started ? pointIcon(p.points_earned) : { icon: "🔒", color: "text-white/20", label: "wyniki ukryte" };
              return (
                <div key={i} className="bg-[#111] border border-white/[0.06] rounded-2xl px-4 py-3 flex items-center gap-3">
                  {pi.icon && <span className="text-2xl leading-none">{pi.icon}</span>}
                  <div className="flex-1 min-w-0">
                    <p className="text-white font-bold text-sm truncate">{p.match_home} – {p.match_away}</p>
                    <p className="text-white/40 text-xs font-mono mt-0.5">
                      Typ: {p.predicted_h}:{p.predicted_a}
                      {started && p.real_h != null && <span className="text-white/30"> · wynik: {p.real_h}:{p.real_a}</span>}
                      {!started && p.match_time && <span className="text-white/20"> · start: {new Date(p.match_time).toLocaleTimeString("pl-PL", { hour: "2-digit", minute: "2-digit" })}</span>}
                    </p>
                  </div>
                  <p className={`font-black text-sm flex-shrink-0 ${pi.color}`}>{started ? pi.label : "—"}</p>
                </div>
              );
            })}
          </div>
        )
      )}
    </div>
  );
}
