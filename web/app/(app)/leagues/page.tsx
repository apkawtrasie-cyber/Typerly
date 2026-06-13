"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase, League, generateInviteCode } from "@/lib/supabase";
import Link from "next/link";
import { Plus, LogIn, Users, Crown, Copy, Check, X } from "lucide-react";

type LeagueWithCount = League & { memberCount: number; isAdmin: boolean };

export default function LeaguesPage() {
  const [leagues, setLeagues] = useState<LeagueWithCount[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [dialog, setDialog] = useState<null | "create" | "join">(null);
  const [name, setName] = useState("");
  const [fee, setFee] = useState("0");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    setUserId(user.id);

    // Ligi, których jestem członkiem (leagues + league_members!inner)
    const { data: mine } = await supabase
      .from("leagues")
      .select("*, league_members!inner(user_id)")
      .eq("league_members.user_id", user.id)
      .order("created_at", { ascending: false });

    const list = (mine ?? []) as League[];

    // Liczby członków
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
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  async function createLeague() {
    if (!userId || !name.trim()) return;
    setBusy(true); setError("");
    const invite = generateInviteCode();
    const { data: league, error: e1 } = await supabase
      .from("leagues")
      .insert({ name: name.trim(), admin_id: userId, entry_fee_gemings: parseInt(fee) || 0, invite_code: invite })
      .select().single();
    if (e1 || !league) { setError("Nie udało się utworzyć ligi: " + (e1?.message ?? "")); setBusy(false); return; }
    await supabase.from("league_members").insert({ league_id: league.id, user_id: userId });
    setBusy(false); setDialog(null); setName(""); setFee("0");
    load();
  }

  async function joinLeague() {
    if (!userId || !code.trim()) return;
    setBusy(true); setError("");
    const { data: league } = await supabase
      .from("leagues").select().eq("invite_code", code.trim().toUpperCase()).maybeSingle();
    if (!league) { setError("Nie znaleziono ligi o tym kodzie"); setBusy(false); return; }
    // Sprawdź czy już członek
    const { data: existing } = await supabase
      .from("league_members").select("id").eq("league_id", league.id).eq("user_id", userId).maybeSingle();
    if (!existing) {
      const { error: e2 } = await supabase.from("league_members").insert({ league_id: league.id, user_id: userId });
      if (e2) { setError("Nie udało się dołączyć: " + e2.message); setBusy(false); return; }
    }
    setBusy(false); setDialog(null); setCode("");
    load();
  }

  function copyCode(c: string) {
    navigator.clipboard.writeText(c);
    setCopied(c);
    setTimeout(() => setCopied(null), 1500);
  }

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      <div className="flex items-center justify-between mb-5">
        <h1 className="text-white font-black text-2xl font-archivo">Ligi</h1>
        <div className="flex gap-2">
          <button onClick={() => { setDialog("join"); setError(""); }}
            className="flex items-center gap-1.5 bg-[#111] border border-white/[0.06] text-white/70 text-sm font-bold px-3 py-2 rounded-xl active:scale-95 transition">
            <LogIn size={15} /> Dołącz
          </button>
          <button onClick={() => { setDialog("create"); setError(""); }}
            className="flex items-center gap-1.5 bg-[#F5C400] text-black text-sm font-black px-3 py-2 rounded-xl active:scale-95 transition">
            <Plus size={15} /> Stwórz
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col gap-3">{[0,1,2].map(i => <div key={i} className="skeleton h-20 rounded-2xl" />)}</div>
      ) : leagues.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-5xl mb-3">🏆</p>
          <p className="text-white/60 font-bold mb-1">Brak lig</p>
          <p className="text-white/30 text-sm mb-5">Stwórz własną ligę lub dołącz kodem znajomych</p>
          <button onClick={() => setDialog("create")} className="bg-[#F5C400] text-black font-black px-6 py-3 rounded-xl active:scale-95 transition">
            Stwórz pierwszą ligę
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
        </div>
      )}

      {/* Dialog Stwórz / Dołącz */}
      {dialog && (
        <div onClick={() => setDialog(null)} className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-end sm:items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-white font-black text-lg font-archivo">{dialog === "create" ? "Nowa liga" : "Dołącz do ligi"}</h2>
              <button onClick={() => setDialog(null)} className="text-white/40"><X size={20} /></button>
            </div>

            {dialog === "create" ? (
              <div className="flex flex-col gap-3">
                <input value={name} onChange={e => setName(e.target.value)} placeholder="Nazwa ligi"
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                <div>
                  <label className="text-white/40 text-xs font-semibold mb-1 block">Wpisowe (gemings)</label>
                  <input value={fee} onChange={e => setFee(e.target.value)} type="number" min="0"
                    className="w-full bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#F5C400]/40" />
                </div>
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={createLeague} disabled={busy || !name.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? "Tworzenie..." : "Stwórz ligę"}
                </button>
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                <input value={code} onChange={e => setCode(e.target.value.toUpperCase())} placeholder="Kod zaproszenia" maxLength={6}
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white text-center text-lg font-mono tracking-widest placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={joinLeague} disabled={busy || !code.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? "Dołączanie..." : "Dołącz"}
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
