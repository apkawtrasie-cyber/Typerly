"use client";
import { useEffect, useRef, useState, useCallback } from "react";
import { supabase, ChatMessage, ChatRoom } from "@/lib/supabase";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Send } from "lucide-react";

export default function ChatRoomPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [room, setRoom] = useState<ChatRoom | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [text, setText] = useState("");
  const [userId, setUserId] = useState<string | null>(null);
  const [username, setUsername] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);

  const scrollDown = useCallback(() => {
    requestAnimationFrame(() => bottomRef.current?.scrollIntoView({ behavior: "smooth" }));
  }, []);

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      setUserId(user?.id ?? null);
      if (user) {
        const { data: profile } = await supabase.from("profiles").select("username").eq("id", user.id).single();
        setUsername(profile?.username ?? "");
      }
      const [{ data: r }, { data: msgs }] = await Promise.all([
        supabase.from("chat_rooms").select("*").eq("id", id).single(),
        supabase.from("chat_messages").select("*").eq("room_id", id).order("created_at", { ascending: true }).limit(200),
      ]);
      setRoom(r);
      setMessages((msgs ?? []) as ChatMessage[]);
      scrollDown();
    }
    load();

    const sub = supabase.channel(`room-${id}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "chat_messages", filter: `room_id=eq.${id}` },
        payload => {
          setMessages(prev => {
            const m = payload.new as ChatMessage;
            if (prev.some(x => x.id === m.id)) return prev;
            return [...prev, m];
          });
          scrollDown();
        })
      .subscribe();

    return () => { supabase.removeChannel(sub); };
  }, [id, scrollDown]);

  async function send() {
    if (!userId || !text.trim()) return;
    const content = text.trim();
    setText("");
    await supabase.from("chat_messages").insert({ room_id: id, user_id: userId, username: username || "Gracz", content });
  }

  return (
    <div className="flex flex-col h-[calc(100vh-72px)]">
      {/* Header */}
      <div className="px-4 pt-5 pb-3 border-b border-white/[0.06] flex items-center gap-3">
        <button onClick={() => router.back()} className="text-white/40"><ArrowLeft size={20} /></button>
        <h1 className="text-white font-black text-lg font-archivo flex-1 truncate">{room?.name ?? "Czat"}</h1>
      </div>

      {/* Wiadomości */}
      <div className="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
        {messages.length === 0 ? (
          <p className="text-white/20 text-sm text-center py-8">Brak wiadomości — napisz pierwszy! 👋</p>
        ) : messages.map(m => {
          const mine = m.user_id === userId;
          return (
            <div key={m.id} className={`flex flex-col ${mine ? "items-end" : "items-start"}`}>
              {!mine && <span className="text-white/30 text-[10px] mb-0.5 px-1">{m.username}</span>}
              <div className={`px-4 py-2 rounded-2xl text-sm max-w-[80%] ${mine ? "bg-[#F5C400] text-black font-medium rounded-br-md" : "bg-[#1a1a1a] text-white rounded-bl-md"}`}>
                {m.content}
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Pole wpisywania */}
      <div className="px-4 py-3 border-t border-white/[0.06] flex gap-2"
        style={{ paddingBottom: "max(12px, env(safe-area-inset-bottom))" }}>
        <input value={text} onChange={e => setText(e.target.value)}
          onKeyDown={e => e.key === "Enter" && send()}
          placeholder="Napisz wiadomość..."
          className="flex-1 bg-[#111] border border-white/[0.06] rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40" />
        <button onClick={send} disabled={!text.trim()}
          className="bg-[#F5C400] text-black p-3 rounded-xl disabled:opacity-40 active:scale-95 transition">
          <Send size={18} />
        </button>
      </div>
    </div>
  );
}
