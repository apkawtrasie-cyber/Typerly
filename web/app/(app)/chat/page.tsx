"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback } from "react";
import { supabase, ChatRoom, generateInviteCode } from "@/lib/supabase";
import Link from "next/link";
import { Plus, LogIn, X, MessageCircle } from "lucide-react";
import { useLang } from "@/contexts/LangContext";

type RoomWithMeta = ChatRoom & { lastMessage: string | null; lastAt: string | null };

export default function ChatPage() {
  const { t } = useLang();
  const [rooms, setRooms] = useState<RoomWithMeta[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(true);
  const [dialog, setDialog] = useState<null | "create" | "join">(null);
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    setUserId(user.id);

    const { data: profile } = await supabase.from("profiles").select("username").eq("id", user.id).single();
    setUsername(profile?.username ?? "");

    // Moje pokoje (chat_rooms + chat_members!inner) — tylko grupy (bez czatów meczowych)
    const { data: myRooms } = await supabase
      .from("chat_rooms")
      .select("*, chat_members!inner(user_id)")
      .eq("chat_members.user_id", user.id)
      .is("match_id", null)
      .order("created_at", { ascending: false });

    const list = (myRooms ?? []) as ChatRoom[];

    // Ostatnia wiadomość dla każdego pokoju
    const withMeta: RoomWithMeta[] = await Promise.all(list.map(async (r) => {
      const { data: last } = await supabase
        .from("chat_messages").select("content, created_at, username")
        .eq("room_id", r.id).order("created_at", { ascending: false }).limit(1).maybeSingle();
      return {
        ...r,
        lastMessage: last ? `${last.username}: ${last.content}` : null,
        lastAt: last?.created_at ?? null,
      };
    }));
    withMeta.sort((a, b) => (b.lastAt ?? b.created_at).localeCompare(a.lastAt ?? a.created_at));
    setRooms(withMeta);
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  async function createRoom() {
    if (!userId || !name.trim()) return;
    setBusy(true); setError("");
    const invite = generateInviteCode();
    const { data: room, error: e1 } = await supabase
      .from("chat_rooms")
      .insert({ name: name.trim(), created_by: userId, invite_code: invite })
      .select().single();
    if (e1 || !room) { setError(t("chat.create_error") + ": " + (e1?.message ?? "")); setBusy(false); return; }
    await supabase.from("chat_members").insert({ room_id: room.id, user_id: userId, role: "admin" });
    setBusy(false); setDialog(null); setName("");
    load();
  }

  async function joinRoom() {
    if (!userId || !code.trim()) return;
    setBusy(true); setError("");
    const { data: room } = await supabase
      .from("chat_rooms").select().eq("invite_code", code.trim().toUpperCase()).maybeSingle();
    if (!room) { setError(t("chat.group_not_found")); setBusy(false); return; }
    const { data: existing } = await supabase
      .from("chat_members").select("user_id").eq("room_id", room.id).eq("user_id", userId).maybeSingle();
    if (!existing) {
      const { error: e2 } = await supabase.from("chat_members").insert({ room_id: room.id, user_id: userId, role: "member" });
      if (e2) { setError(t("chat.join_error") + ": " + e2.message); setBusy(false); return; }
    }
    setBusy(false); setDialog(null); setCode("");
    load();
  }

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      <div className="flex items-center justify-between mb-5">
        <h1 className="text-white font-black text-2xl font-archivo">{t("chat.title")}</h1>
        <div className="flex gap-2">
          <button onClick={() => { setDialog("join"); setError(""); }}
            className="flex items-center gap-1.5 bg-[#1e1e1e] border border-white/[0.12] text-white/70 text-sm font-bold px-3 py-2 rounded-xl active:scale-95 transition">
            <LogIn size={15} /> {t("dialog.join")}
          </button>
          <button onClick={() => { setDialog("create"); setError(""); }}
            className="flex items-center gap-1.5 bg-[#F5C400] text-black text-sm font-black px-3 py-2 rounded-xl active:scale-95 transition">
            <Plus size={15} /> {t("chat.group_btn")}
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col gap-3">{[0,1,2].map(i => <div key={i} className="skeleton h-16 rounded-2xl" />)}</div>
      ) : rooms.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-5xl mb-3">💬</p>
          <p className="text-white/60 font-bold mb-1">{t("chat.no_groups")}</p>
          <p className="text-white/30 text-sm mb-5">{t("chat.no_groups_sub")}</p>
          <button onClick={() => setDialog("create")} className="bg-[#F5C400] text-black font-black px-6 py-3 rounded-xl active:scale-95 transition">
            {t("chat.create_first")}
          </button>
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {rooms.map(r => (
            <Link key={r.id} href={`/chat/${r.id}`}>
              <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl p-4 flex items-center gap-3 active:scale-[0.98] transition">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-[#F5C400]/20 to-[#F5C400]/5 border border-[#F5C400]/20 flex items-center justify-center flex-shrink-0">
                  <MessageCircle size={20} className="text-[#F5C400]" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="text-white font-bold truncate">{r.name}</h3>
                  <p className="text-white/30 text-xs truncate">{r.lastMessage ?? t("chat.last_empty")}</p>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}

      {/* Dialog */}
      {dialog && (
        <div onClick={() => setDialog(null)} className="fixed inset-0 z-[60] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div onClick={e => e.stopPropagation()} className="bg-[#141414] border border-white/10 rounded-3xl p-5 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-white font-black text-lg font-archivo">{dialog === "create" ? t("chat.new_group") : t("chat.join_group")}</h2>
              <button onClick={() => setDialog(null)} className="text-white/40"><X size={20} /></button>
            </div>
            {dialog === "create" ? (
              <div className="flex flex-col gap-3">
                <input value={name} onChange={e => setName(e.target.value)} placeholder={t("chat.group_name")}
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={createRoom} disabled={busy || !name.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? t("dialog.creating") : t("chat.create_group")}
                </button>
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                <input value={code} onChange={e => setCode(e.target.value.toUpperCase())} placeholder={t("dialog.join_code_placeholder")} maxLength={6}
                  className="bg-[#0A0A0A] border border-white/10 rounded-xl px-4 py-3 text-white text-center text-lg font-mono tracking-widest placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
                {error && <p className="text-red-400 text-sm">{error}</p>}
                <button onClick={joinRoom} disabled={busy || !code.trim()}
                  className="bg-[#F5C400] text-black font-black py-3 rounded-xl mt-1 disabled:opacity-40 active:scale-95 transition">
                  {busy ? t("dialog.joining") : t("dialog.join")}
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
