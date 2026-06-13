"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { Trophy, CheckCircle2, XCircle, Loader2 } from "lucide-react";

export default function JoinPage() {
  const router = useRouter();
  const params = useSearchParams();
  const code = params.get("code")?.toUpperCase() ?? "";
  const [status, setStatus] = useState<"loading" | "joining" | "success" | "already" | "notfound" | "login">("loading");
  const [name, setName] = useState("");

  useEffect(() => {
    if (!code) { router.replace("/leagues"); return; }
    join();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [code]);

  async function join() {
    setStatus("joining");
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      // Store code in sessionStorage, redirect to login
      sessionStorage.setItem("pending_join_code", code);
      router.push(`/login?redirect=/join?code=${code}`);
      return;
    }

    // Find tournament by code
    const { data: t } = await supabase
      .from("custom_tournaments")
      .select("id, name")
      .eq("invite_code", code)
      .maybeSingle();

    if (!t) { setStatus("notfound"); return; }
    setName(t.name);

    // Check if already a member
    const { data: existing } = await supabase
      .from("tournament_members")
      .select("id")
      .eq("tournament_id", t.id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (existing) { setStatus("already"); setTimeout(() => router.push(`/tournaments/${t.id}`), 1500); return; }

    // Join
    const { error } = await supabase.from("tournament_members").insert({ tournament_id: t.id, user_id: user.id });
    if (error) { setStatus("notfound"); return; }

    setStatus("success");
    setTimeout(() => router.push(`/tournaments/${t.id}`), 1800);
  }

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-[#080808]">
      <div className="w-full max-w-xs text-center">
        {(status === "loading" || status === "joining") && (
          <>
            <Loader2 size={48} className="text-[#F5C400] animate-spin mx-auto mb-4" />
            <p className="text-white font-bold text-lg">Dołączanie do turnieju...</p>
            <p className="text-white/40 text-sm mt-1 font-mono">{code}</p>
          </>
        )}
        {status === "success" && (
          <>
            <CheckCircle2 size={56} className="text-green-400 mx-auto mb-4" />
            <p className="text-white font-black text-xl">Dołączono! 🎉</p>
            <p className="text-white/50 text-sm mt-1">{name}</p>
            <p className="text-white/30 text-xs mt-3">Przekierowanie...</p>
          </>
        )}
        {status === "already" && (
          <>
            <Trophy size={56} className="text-[#F5C400] mx-auto mb-4" />
            <p className="text-white font-black text-xl">Już jesteś członkiem</p>
            <p className="text-white/50 text-sm mt-1">{name}</p>
            <p className="text-white/30 text-xs mt-3">Przekierowanie...</p>
          </>
        )}
        {status === "notfound" && (
          <>
            <XCircle size={56} className="text-red-400 mx-auto mb-4" />
            <p className="text-white font-black text-xl">Nie znaleziono turnieju</p>
            <p className="text-white/40 text-sm mt-1">Kod <span className="font-mono text-white/60">{code}</span> jest nieprawidłowy</p>
            <button onClick={() => router.push("/leagues")}
              className="mt-6 w-full bg-[#F5C400] text-black font-black py-4 rounded-2xl">
              Wróć do lig
            </button>
          </>
        )}
      </div>
    </div>
  );
}
