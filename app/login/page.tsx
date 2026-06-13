"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Image from "next/image";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  function translateError(msg: string) {
    const m = msg.toLowerCase();
    if (m.includes("invalid login") || m.includes("invalid credentials") || m.includes("password")) return "Hasło nieprawidłowe";
    if (m.includes("user not found") || m.includes("no user")) return "Nie znaleziono konta";
    if (m.includes("email not confirmed")) return "Potwierdź email przed logowaniem";
    if (m.includes("too many")) return "Zbyt wiele prób — spróbuj później";
    if (m.includes("network") || m.includes("fetch")) return "Błąd połączenia z internetem";
    return "Błąd logowania — spróbuj ponownie";
  }

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) setError(translateError(error.message));
    else router.push("/home");
  }

  return (
    <div className="min-h-screen bg-[#0A0A0A] flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex flex-col items-center mb-10">
          <div className="relative mb-5">
            <div className="absolute inset-0 rounded-full bg-[#F5C400] opacity-30 blur-2xl scale-110" />
            <Image
              src="/icons/icon-512.png"
              alt="Typerly"
              width={100}
              height={100}
              className="relative rounded-full"
            />
          </div>
          <h1 className="font-archivo font-black text-4xl tracking-widest">
            <span className="text-white">TYPE</span>
            <span className="text-[#F5C400]">RLY</span>
          </h1>
          <p className="text-white/30 text-[10px] font-bold tracking-[3px] mt-1">
            TYPUJ · RYWALIZUJ · WYGRYWAJ
          </p>
        </div>

        {/* Formularz */}
        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">Email</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="Twój adres email"
              required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition"
            />
          </div>
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">Hasło</label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="Twoje hasło"
              required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition"
            />
          </div>

          {error && (
            <p className="text-red-400 text-sm text-center font-semibold">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#F5C400] text-black font-black text-base py-4 rounded-xl mt-2 disabled:opacity-50 active:scale-95 transition"
          >
            {loading ? "Logowanie..." : "Zaloguj się"}
          </button>
        </form>

        <div className="flex items-center justify-center gap-2 mt-6">
          <span className="text-white/40 text-sm">Nie masz konta?</span>
          <a href="/register" className="text-[#F5C400] font-bold text-sm">Zarejestruj się</a>
        </div>
      </div>
    </div>
  );
}
