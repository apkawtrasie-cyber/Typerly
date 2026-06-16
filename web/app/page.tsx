"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

// Strona startowa — sprawdza sesję po stronie klienta (localStorage)
// i przekierowuje. Brak sprawdzania serwerowego = brak wylogowywania.
export default function RootPage() {
  const router = useRouter();
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      router.replace(data.session ? "/home" : "/login");
    });
  }, [router]);

  return (
    <div className="min-h-[100dvh] bg-[#0A0A0A] flex items-center justify-center">
      <div className="w-8 h-8 border-2 border-[#F5C400] border-t-transparent rounded-full animate-spin" />
    </div>
  );
}
