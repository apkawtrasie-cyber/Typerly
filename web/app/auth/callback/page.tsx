"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

// Powrót z logowania Google (OAuth). Klient wymienia ?code= na sesję
// (weryfikator PKCE leży w localStorage z momentu signInWithOAuth),
// po czym przechodzi do aplikacji.
export default function AuthCallbackPage() {
  const router = useRouter();
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      const code = new URLSearchParams(window.location.search).get("code");
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (error) { setError(error.message); return; }
      }
      // Upewnij się, że sesja jest aktywna, i wejdź do aplikacji
      const { data } = await supabase.auth.getSession();
      router.replace(data.session ? "/home" : "/login");
    })();
  }, [router]);

  return (
    <div className="min-h-[100dvh] bg-[#0A0A0A] flex flex-col items-center justify-center gap-4 px-6 text-center">
      {error ? (
        <>
          <p className="text-4xl">⚠️</p>
          <p className="text-white/60 text-sm">{error}</p>
          <a href="/login" className="text-[#F5C400] font-bold text-sm">Wróć do logowania</a>
        </>
      ) : (
        <div className="w-8 h-8 border-2 border-[#F5C400] border-t-transparent rounded-full animate-spin" />
      )}
    </div>
  );
}
