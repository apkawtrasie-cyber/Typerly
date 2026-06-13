"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase, League, Match, isUpcoming, isLive } from "@/lib/supabase";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Crown, Copy, Check, MoreVertical, Pencil, Trash2, LogOut, X, ChevronRight } from "lucide-react";
import { TeamLogo } from "@/components/MatchCard";

type Member = { user_id: string; username: string; points: number; predictions: number };

export default function LeagueDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [league, setLeague] = useState<League | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [matches, setMatches] = useState<Match[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editName, setEditName] = useState("");
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    setUserId(user?.id ?? null);

    const [{ data: lg }, { data: mem }] = await Promise.all([
      supabase.from("leagues").select("*").eq("id", id).single(),
      supabase.from("league_members").select("user_id, profiles(username)").eq("league_id", id),
    ]);
    setLeague(lg);

    const memberRows = (mem ?? []) as { user_id: string; profiles: { username: string } | { username: string }[] | null }[];

    // Punkty członków w tej lidze (predictions.league_id = id)
    const { data: preds } = await supabase
      .from("predictions")
      .select("user_id, points_earned, is_calculated")
      .eq("league_id", id);

    const pts: Record<string, number> = {};
    const cnt: Record<string, number> = {};
    for (const p of (preds ?? []) as { user_id: string; points_earned: number | null; is_calculated: boolean }[]) {
      cnt[p.user_id] = (cnt[p.user_id] ?? 0) + 1;
      if (p.is_calculated) pts[p.user_id] = (pts[p.user_id] ?? 0) + (p.points_earned ?? 0);
    }

    const list: Member[] = memberRows.map(m => {
      const prof = Array.isArray(m.profiles) ? m.profiles[0] : m.profiles;
      return {
        user_id: m.user_id,
        username: prof?.username ?? "Gracz",
        points: pts[m.user_id] ?? 0,
        predictions: cnt[m.user_id] ?? 0,
      };
    });
    list.sort((a, b) => b.points - a.points);
    setMembers(list);

    // Nadchodzące mecze do typowania w tej grupie
    const since = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    const { data: ms } = await supabase
      .from("matches")
      .select("*")
      .gte("match_time", since)
      .order("match_time", { ascending: true })
      .limit(30);
    setMatches((ms ?? []) as Match[]);

    setLoading(false);
  }, [id]);

  useEffect(() => { load(); }, [load]);

  function copyCode() {
    if (!league) return;
    navigator.clipboard.writeText(league.invite_code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  async function saveRename() {
    if (!league || !editName.trim()) return;
    setBusy(true);
    await supabase.from("leagues").update({ name: editName.trim() }).eq("id", league.id);
    setBusy(false); setEditing(false);
    load();
  }

  async function deleteLeague() {
    if (!league) return;
    setBusy(true);
    // Najpierw usuń członków (gdy brak kaskady), potem ligę
    await supabase.from("league_members").delete().eq("league_id", league.id);
    const { error } = await supabase.from("leagues").delete().eq("id", league.id);
    setBusy(false);
    if (!error) router.push("/leagues");
  }

  async function leaveLeague() {
    if (!league || !userId) return;
    setBusy(true);
    await supabase.from("league_members").delete().eq("league_id", league.id).eq("user_id", userId);
    setBusy(false);
    router.push("/leagues");
  }

  if (loading || !league) return (
    <div className="flex justify-center pt-20"><div className="w-8 h-8 border-2 border-[#F5C400] border-t-transparent rounded-full animate-spin" /></div>
  );

  const medals = ["🥇", "🥈", "🥉"];
  const isAdmin = userId === league.admin_id;

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      <div className="flex items-center justify-between mb-4">
        <button onClick={() => router.back()} className="text-white/40 flex items-center gap-1 text-sm">
          <ArrowLeft size={18} /> Wróć
        </button>

        {/* Menu trzy kropki */}
        <div className="relative">
          <button onClick={() => setMenuOpen(v => !v)} className="text-white/50 p-1.5 rounded-lg hover:bg-white/5 transition">
            <MoreVertical size={20} />
          </button>
          {menuOpen && (
            <>
              <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} />
              <div className="absolute right-0 top-9 z-50 bg-[#1a1a1a] border border-white/10 rounded-xl overflow-hidden w-48 shadow-xl">
                {isAdmin ? (
                  <>
                    <button onClick={() => { setMenuOpen(false); setEditName(league.name); setEditing(true); }}
                      className="w-full flex items-center gap-3 px-4 py-3 text-white/80 text-sm hover:bg-white/5 transition">
                      <Pencil size={15} /> Edytuj nazwę
                    </button>
                    <button onClick={() => { setMenuOpen(false); setConfirmDelete(true); }}
                      className="w-full flex items-center gap-3 px-4 py-3 text-red-400 text-sm hover:bg-red-500/10 transition border-t border-white/[0.06]">
                      <Trash2 size={15} /> Usuń ligę
                    </button>
                  </>
                ) : (
                  <button onClick={() => { setMenuOpen(false); setConfirmLeave(true); }}
                    className="w-full flex items-center gap-3 px-4 py-3 text-red-400 text-sm hover:bg-red-500/10 transition">
                    <LogOut size={15} /> Opuść grupę
                  </button>
                )}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Nagłówek ligi */}
      <div className="bg-gradient-to-br from-[#1a1500] to-[#111] border border-[#F5C400]/20 rounded-2xl p-5 mb-6 text-center">
        <div className="text-4xl mb-2">🏆</div>
        <h1 className="text-white font-black text-xl font-archivo">{league.name}</h1>
        <button onClick={copyCode} className="inline-flex items-center gap-1.5 mt-3 bg-black/30 border border-white/10 rounded-full px-3 py-1.5 text-sm">
          {copied ? <Check size={13} className="text-green-400" /> : <Copy size={13} className="text-white/50" />}
          <span className="text-white/70 font-mono tracking-widest">{league.invite_code}</span>
        </button>
        <p className="text-white/30 text-xs mt-2">Udostępnij kod, by zaprosić znajomych</p>
      </div>

      {/* Ranking */}
      <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">Ranking ({members.length})</h2>
      <div className="flex flex-col gap-2">
        {members.map((m, i) => (
          <div key={m.user_id} className={`flex items-center gap-3 rounded-xl px-4 py-3 border ${m.user_id === userId ? "border-[#F5C400]/40 bg-[#F5C400]/5" : "border-white/[0.06] bg-[#111]"}`}>
            <span className="w-7 text-center font-black text-sm">
              {i < 3 ? <span className="text-lg">{medals[i]}</span> : <span className="text-white/30">{i + 1}</span>}
            </span>
            <div className="flex-1 flex items-center gap-2 min-w-0">
              <span className="text-white font-semibold text-sm truncate">{m.username}</span>
              {m.user_id === league.admin_id && <Crown size={12} className="text-[#F5C400] flex-shrink-0" />}
            </div>
            <span className="text-white/30 text-xs">{m.predictions} typów</span>
            <span className="text-[#F5C400] font-black tabular-nums w-14 text-right">{m.points} pkt</span>
          </div>
        ))}
      </div>

      {/* Mecze do typowania w grupie */}
      <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mt-7 mb-3">Mecze do typowania</h2>
      {(() => {
        const upcoming = matches.filter(m => isUpcoming(m.status) || isLive(m.status));
        if (upcoming.length === 0) {
          return <p className="text-white/20 text-sm text-center py-6">Brak nadchodzących meczów</p>;
        }
        return (
          <div className="flex flex-col gap-2">
            {upcoming.map(m => (
              <Link key={m.id} href={`/matches/${m.id}?league=${league.id}`}>
                <div className="flex items-center gap-2 bg-[#111] border border-white/[0.06] rounded-xl px-3 py-3 active:scale-[0.98] transition">
                  <TeamLogo url={m.home_team_logo_url} name={m.home_team_name} />
                  <span className="flex-1 text-white text-xs font-semibold text-center truncate">{m.home_team_name}</span>
                  <span className="text-white/20 text-[10px] font-black px-1.5">VS</span>
                  <span className="flex-1 text-white text-xs font-semibold text-center truncate">{m.away_team_name}</span>
                  <TeamLogo url={m.away_team_logo_url} name={m.away_team_name} />
                  <ChevronRight size={16} className="text-white/20 flex-shrink-0" />
                </div>
              </Link>
            ))}
          </div>
        );
      })()}

      {/* Dialog: edycja nazwy */}
      {editing && (
        <div onClick={() => setEditing(false)} className="fixed inset-0 z-[60] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-white font-black text-lg font-archivo">Edytuj nazwę</h2>
              <button onClick={() => setEditing(false)} className="text-white/40"><X size={20} /></button>
            </div>
            <input value={editName} onChange={e => setEditName(e.target.value)} autoFocus
              className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#F5C400]/40 mb-3" />
            <button onClick={saveRename} disabled={busy || !editName.trim()}
              className="w-full bg-[#F5C400] text-black font-black py-3 rounded-xl disabled:opacity-40 active:scale-95 transition">
              {busy ? "Zapisywanie..." : "Zapisz"}
            </button>
          </div>
        </div>
      )}

      {/* Dialog: potwierdź usunięcie */}
      {confirmDelete && (
        <div onClick={() => setConfirmDelete(false)} className="fixed inset-0 z-[60] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm text-center">
            <div className="text-4xl mb-3">🗑️</div>
            <h2 className="text-white font-black text-lg mb-1">Usunąć ligę?</h2>
            <p className="text-white/50 text-sm mb-5">Liga „{league.name}" zostanie trwale usunięta wraz z członkami. Tej operacji nie można cofnąć.</p>
            <div className="flex gap-3">
              <button onClick={() => setConfirmDelete(false)} className="flex-1 bg-white/5 border border-white/10 text-white/70 font-bold py-3 rounded-xl active:scale-95 transition">Anuluj</button>
              <button onClick={deleteLeague} disabled={busy} className="flex-1 bg-red-500 text-white font-black py-3 rounded-xl disabled:opacity-40 active:scale-95 transition">
                {busy ? "Usuwanie..." : "Usuń"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Dialog: potwierdź opuszczenie */}
      {confirmLeave && (
        <div onClick={() => setConfirmLeave(false)} className="fixed inset-0 z-[60] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm text-center">
            <div className="text-4xl mb-3">👋</div>
            <h2 className="text-white font-black text-lg mb-1">Opuścić grupę?</h2>
            <p className="text-white/50 text-sm mb-5">Przestaniesz być członkiem ligi „{league.name}". Możesz dołączyć ponownie kodem.</p>
            <div className="flex gap-3">
              <button onClick={() => setConfirmLeave(false)} className="flex-1 bg-white/5 border border-white/10 text-white/70 font-bold py-3 rounded-xl active:scale-95 transition">Anuluj</button>
              <button onClick={leaveLeague} disabled={busy} className="flex-1 bg-red-500 text-white font-black py-3 rounded-xl disabled:opacity-40 active:scale-95 transition">
                {busy ? "..." : "Opuść"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
