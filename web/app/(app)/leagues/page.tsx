"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase, League, generateInviteCode } from "@/lib/supabase";
import Link from "next/link";
import { Users, Crown, Copy, Check, X, Trophy, Gift, Trash2, Pencil } from "lucide-react";
import { useLang } from "@/contexts/LangContext";

type LeagueWithCount = League & { memberCount: number; isAdmin: boolean };
type Tournament = {
  id: string;
  name: string;
  admin_id: string;
  invite_code: string;
  prize_description: string | null;
  created_at: string;
  isAdmin: boolean;
};

export default function LeaguesPage() {
  const { t: tr } = useLang();
  const [leagues, setLeagues] = useState<LeagueWithCount[]>([]);
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [dialog, setDialog] = useState<null | "create" | "join" | "tournament">(null);
  const [name, setName] = useState("");
  const [fee, setFee] = useState("0");
  const [prize, setPrize] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState<string | null>(null);
  const [delTournament, setDelTournament] = useState<Tournament | null>(null);
  const [editTournamentId, setEditTournamentId] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    setUserId(user.id);

    // Ligi, których jestem członkiem
    const { data: mine } = await supabase
      .from("leagues")
      .select("*, league_members!inner(user_id)")
      .eq("league_members.user_id", user.id)
      .order("created_at", { ascending: false });
    const list = (mine ?? []) as League[];

    const counts: Record<string, number> = {};
    if (list.length > 0) {
      const { data: members } = await supabase
        .from("league_members")
        .select("league_id")
        .in("league_id", list.map(l => l.id));
      for (const m of (members ?? []) as { league_id: string }[]) {
        counts[m.league_id] = (counts[m.league_id] ?? 0) + 1;
      }
    }
    setLeagues(list.map(l => ({ ...l, memberCount: counts[l.id] ?? 1, isAdmin: l.admin_id === user.id })));

    // Turnieje (admin + członkostwo)
    try {
      const { data: adminT } = await supabase
        .from("custom_tournaments").select("*").eq("admin_id", user.id);
      const { data: memberRows } = await supabase
        .from("tournament_members").select("tournament_id").eq("user_id", user.id);
      const memberIds = (memberRows ?? []).map((r: { tournament_id: string }) => r.tournament_id);
      const map: Record<string, Tournament> = {};
      for (const t of (adminT ?? []) as Tournament[]) map[t.id] = { ...t, isAdmin: true };
      if (memberIds.length > 0) {
        const { data: memberT } = await supabase
          .from("custom_tournaments").select("*").in("id", memberIds);
        for (const t of (memberT ?? []) as Tournament[]) {
          if (!map[t.id]) map[t.id] = { ...t, isAdmin: t.admin_id === user.id };
        }
      }
      setTournaments(Object.values(map).sort((a, b) => b.created_at.localeCompare(a.created_at)));
    } catch {
      setTournaments([]);
    }

    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  // Mapowanie akcji FAB → typ dialogu
  function openFromAction(action: string | null) {
    setError("");
    if (action === "create-league") setDialog("create");
    else if (action === "create-tournament") setDialog("tournament");
    else if (action === "join") setDialog("join");
  }

  // Odczyt intencji z FAB przy wejściu z innej zakładki (?fab=...)
  useEffect(() => {
    const fab = new URLSearchParams(window.location.search).get("fab");
    if (fab) { openFromAction(fab); window.history.replaceState({}, "", "/leagues"); }
  }, []);

  // Nasłuch zdarzenia z FAB, gdy już jesteśmy na stronie Ligi
  useEffect(() => {
    const handler = (e: Event) => openFromAction((e as CustomEvent).detail as string);
    window.addEventListener("typerly-fab", handler);
    return () => window.removeEventListener("typerly-fab", handler);
  }, []);

  async function createLeague() {
    if (!userId || !name.trim()) return;
    setBusy(true); setError("");
    const invite = generateInviteCode();
    const { data: league, error: e1 } = await supabase
      .from("leagues")
      .insert({ name: name.trim(), admin_id: userId, entry_fee_gemings: parseInt(fee) || 0, invite_code: invite })
      .select().single();
    if (e1 || !league) { setError(tr("leagues.create_error") + ": " + (e1?.message ?? "")); setBusy(false); return; }
    await supabase.from("league_members").insert({ league_id: league.id, user_id: userId });
    setBusy(false); setDialog(null); setName(""); setFee("0");
    load();
  }

  async function saveTournament() {
    if (!userId || !name.trim()) return;
    setBusy(true); setError("");

    // Edycja istniejącego turnieju (twórca może edytować)
    if (editTournamentId) {
      const { error } = await supabase.from("custom_tournaments")
        .update({ name: name.trim(), prize_description: prize.trim() || null })
        .eq("id", editTournamentId);
      setBusy(false);
      if (error) { setError(tr("leagues.save_error") + ": " + error.message); return; }
      closeDialog(); load(); return;
    }

    // Nowy turniej
    const invite = generateInviteCode();
    const { data: t, error: e1 } = await supabase
      .from("custom_tournaments")
      .insert({ name: name.trim(), admin_id: userId, invite_code: invite, prize_description: prize.trim() || null })
      .select().single();
    if (e1 || !t) { setError(tr("leagues.tournament_create_error") + ": " + (e1?.message ?? "")); setBusy(false); return; }
    await supabase.from("tournament_members").insert({ tournament_id: t.id, user_id: userId });
    setBusy(false); closeDialog();
    load();
  }

  function closeDialog() {
    setDialog(null); setName(""); setFee("0"); setPrize(""); setCode(""); setError(""); setEditTournamentId(null);
  }

  async function deleteTournament() {
    if (!delTournament) return;
    setBusy(true);
    // Najpierw członkowie (gdy brak kaskady), potem turniej
    await supabase.from("tournament_members").delete().eq("tournament_id", delTournament.id);
    const { error } = await supabase.from("custom_tournaments").delete().eq("id", delTournament.id);
    setBusy(false);
    if (!error) { setDelTournament(null); load(); }
  }

  async function joinByCode() {
    if (!userId || !code.trim()) return;
    setBusy(true); setError("");
    const c = code.trim().toUpperCase();

    // Najpierw szukamy ligi
    const { data: league } = await supabase
      .from("leagues").select().eq("invite_code", c).maybeSingle();
    if (league) {
      const { data: existing } = await supabase
        .from("league_members").select("id").eq("league_id", league.id).eq("user_id", userId).maybeSingle();
      if (!existing) await supabase.from("league_members").insert({ league_id: league.id, user_id: userId });
      setBusy(false); setDialog(null); setCode(""); load(); return;
    }

    // Potem turnieju
    const { data: t } = await supabase
      .from("custom_tournaments").select().eq("invite_code", c).maybeSingle();
    if (t) {
      await supabase.from("tournament_members").upsert({ tournament_id: t.id, user_id: userId });
      setBusy(false); setDialog(null); setCode(""); load(); return;
    }

    setError(tr("dialog.code_not_found"));
    setBusy(false);
  }

  function copyCode(c: string) {
    navigator.clipboard.writeText(c);
    setCopied(c);
    setTimeout(() => setCopied(null), 1500);
  }

  const empty = !loading && leagues.length === 0 && tournaments.length === 0;

  return (
    <div className="px-4 pt-6 fade-in">
      <div className="flex items-center justify-between mb-5">
        <h1 className="text-white font-black text-2xl font-archivo">{tr("leagues.title_full")}</h1>
      </div>

      {loading ? (
        <div className="flex flex-col gap-3">{[0,1,2].map(i => <div key={i} className="skeleton h-20 rounded-2xl" />)}</div>
      ) : empty ? (
        <div className="text-center py-16">
          <p className="text-5xl mb-3">🏆</p>
          <p className="text-white/60 font-bold mb-1">{tr("leagues.empty_title")}</p>
          <p className="text-white/30 text-sm mb-5">{tr("leagues.empty_hint_a")} <span className="text-[#F5C400] font-bold">+</span> {tr("leagues.empty_hint_b")}</p>
          <button onClick={() => setDialog("create")} className="bg-[#F5C400] text-black font-black px-6 py-3 rounded-xl active:scale-95 transition">
            {tr("leagues.create_first")}
          </button>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {leagues.map(l => (
            <Link key={l.id} href={`/leagues/${l.id}`}>
              <div className="bg-[#111] border border-white/[0.06] rounded-2xl p-4 active:scale-[0.98] transition">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#F5C400]/20 to-[#F5C400]/5 border border-[#F5C400]/20 flex items-center justify-center text-2xl flex-shrink-0">🏆</div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <h3 className="text-white font-bold truncate">{l.name}</h3>
                      {l.isAdmin && <Crown size={13} className="text-[#F5C400] flex-shrink-0" />}
                    </div>
                    <div className="flex items-center gap-3 mt-0.5">
                      <span className="flex items-center gap-1 text-white/40 text-xs"><Users size={12} /> {l.memberCount}</span>
                      <button onClick={(e) => { e.preventDefault(); copyCode(l.invite_code); }}
                        className="flex items-center gap-1 text-white/40 text-xs hover:text-[#F5C400] transition">
                        {copied === l.invite_code ? <Check size={12} className="text-green-400" /> : <Copy size={12} />}
                        <span className="font-mono tracking-wider">{l.invite_code}</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </Link>
          ))}

          {tournaments.map(t => (
            <div key={t.id} className="bg-[#111] border border-white/[0.06] rounded-2xl p-4">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500/20 to-purple-500/5 border border-purple-500/20 flex items-center justify-center flex-shrink-0">
                  <Trophy size={22} className="text-purple-400" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="text-white font-bold truncate">{t.name}</h3>
                    {t.isAdmin && <Crown size={13} className="text-[#F5C400] flex-shrink-0" />}
                    <span className="text-[9px] font-black uppercase tracking-wide text-purple-300 bg-purple-500/15 px-1.5 py-0.5 rounded">{tr("leagues.tournament_label")}</span>
                  </div>
                  {t.prize_description && (
                    <p className="flex items-center gap-1 text-white/40 text-xs mt-0.5 truncate"><Gift size={12} /> {t.prize_description}</p>
                  )}
                  <button onClick={() => copyCode(t.invite_code)}
                    className="flex items-center gap-1 text-white/40 text-xs hover:text-[#F5C400] transition mt-0.5">
                    {copied === t.invite_code ? <Check size={12} className="text-green-400" /> : <Copy size={12} />}
                    <span className="font-mono tracking-wider">{t.invite_code}</span>
                  </button>
                </div>
                {t.isAdmin && (
                  <div className="flex items-center flex-shrink-0">
                    <button onClick={() => { setName(t.name); setPrize(t.prize_description ?? ""); setEditTournamentId(t.id); setDialog("tournament"); }}
                      className="text-white/30 hover:text-[#F5C400] p-2 rounded-lg transition" aria-label={tr("dialog.edit_tournament")}>
                      <Pencil size={16} />
                    </button>
                    <button onClick={() => setDelTournament(t)}
                      className="text-white/30 hover:text-red-400 p-2 rounded-lg transition" aria-label={tr("leagues.delete")}>
                      <Trash2 size={17} />
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Dialogi */}
      {dialog && (
        <div onClick={closeDialog} className="fixed inset-0 z-[60] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm mb-4">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-white font-black text-lg font-archivo">
                {dialog === "create" ? tr("dialog.new_league") : dialog === "tournament" ? (editTournamentId ? tr("dialog.edit_tournament") : tr("dialog.new_tournament")) : tr("fab.join_code")}
              </h2>
              <button onClick={closeDialog} className="text-white/40"><X size={20} /></button>
            </div>

            {dialog === "create" && (
              <div className="flex flex-col gap-3">
                <input value={name} onChange={e => setName(e.target.value)} placeholder={tr("dialog.league_name")}
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                <div>
                  <label className="text-white/40 text-xs font-semibold mb-1 block">{tr("dialog.entry_fee")}</label>
                  <input value={fee} onChange={e => setFee(e.target.value)} type="number" min="0"
                    className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#F5C400]/40" />
                </div>
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={createLeague} disabled={busy || !name.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? tr("dialog.creating") : tr("fab.create_league")}
                </button>
              </div>
            )}

            {dialog === "tournament" && (
              <div className="flex flex-col gap-3">
                <input value={name} onChange={e => setName(e.target.value)} placeholder={tr("dialog.tournament_name_placeholder")}
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                <div>
                  <label className="text-white/40 text-xs font-semibold mb-1 block">{tr("dialog.prize_optional")}</label>
                  <input value={prize} onChange={e => setPrize(e.target.value)} placeholder={tr("dialog.prize_placeholder")}
                    className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                </div>
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={saveTournament} disabled={busy || !name.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? tr("league.saving") : editTournamentId ? tr("dialog.save_changes") : tr("fab.create_tournament")}
                </button>
              </div>
            )}

            {dialog === "join" && (
              <div className="flex flex-col gap-3">
                <input value={code} onChange={e => setCode(e.target.value.toUpperCase())} placeholder={tr("dialog.join_code_placeholder")} maxLength={8}
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white text-center text-lg font-mono tracking-widest placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={joinByCode} disabled={busy || !code.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? tr("dialog.joining") : tr("dialog.join")}
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Potwierdzenie usunięcia turnieju */}
      {delTournament && (
        <div onClick={() => setDelTournament(null)} className="fixed inset-0 z-[60] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm text-center mb-4">
            <div className="text-4xl mb-3">🗑️</div>
            <h2 className="text-white font-black text-lg mb-1">{tr("leagues.delete_tournament_q")}</h2>
            <p className="text-white/50 text-sm mb-5">{tr("leagues.tournament_label")} „{delTournament.name}" {tr("leagues.delete_permanent_suffix")}</p>
            <div className="flex gap-3">
              <button onClick={() => setDelTournament(null)} className="flex-1 bg-white/5 border border-white/10 text-white/70 font-bold py-3 rounded-xl active:scale-95 transition">{tr("league.cancel")}</button>
              <button onClick={deleteTournament} disabled={busy} className="flex-1 bg-red-500 text-white font-black py-3 rounded-xl disabled:opacity-40 active:scale-95 transition">
                {busy ? tr("league.deleting") : tr("leagues.delete")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
