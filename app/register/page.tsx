"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Image from "next/image";

export default function RegisterPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { username } },
    });
    setLoading(false);
    if (error) { setError(error.message); return; }

    // Utwórz profil od razu, jeśli sesja jest dostępna (potwierdzanie e-mail wyłączone).
    // Gdy wymagane potwierdzenie — profil powstanie przy pierwszym logowaniu (ProfileGuard).
    if (data.session && data.user) {
      await supabase.from("profiles").upsert(
        { id: data.user.id, username: username.trim(), is_premium: false },
        { onConflict: "id" },
      );
    }
    setSuccess(true);
  }

  if (success) return (
    <div className="min-h-screen bg-[#0A0A0A] flex flex-col items-center justify-center px-6 text-center">
      <div className="text-5xl mb-4">✉️</div>
      <h2 className="text-white font-black text-2xl mb-2">Sprawdź email!</h2>
      <p className="text-white/50 text-sm mb-8">Wysłaliśmy link potwierdzający na <strong className="text-white">{email}</strong></p>
      <a href="/login" className="text-[#F5C400] font-bold">Wróć do logowania</a>
    </div>
  );

  return (
    <div className="min-h-screen bg-[#0A0A0A] flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-sm">
        <div className="flex flex-col items-center mb-10">
          <div className="relative mb-5">
            <div className="absolute inset-0 rounded-full bg-[#F5C400] opacity-30 blur-2xl scale-110" />
            <Image src="/icons/icon-512.png" alt="Typerly" width={90} height={90} className="relative rounded-full" />
          </div>
          <h1 className="font-archivo font-black text-4xl tracking-widest">
            <span className="text-white">TYPE</span><span className="text-[#F5C400]">RLY</span>
          </h1>
          <p className="text-white/30 text-[10px] font-bold tracking-[3px] mt-1">DOŁĄCZ DO GRY</p>
        </div>

        <form onSubmit={handleRegister} className="flex flex-col gap-4">
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">Nazwa użytkownika</label>
            <input type="text" value={username} onChange={e => setUsername(e.target.value)} placeholder="Twój nick" required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition" />
          </div>
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="Twój adres email" required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition" />
          </div>
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">Hasło</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="Min. 6 znaków" required minLength={6}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition" />
          </div>

          {error && <p className="text-red-400 text-sm text-center font-semibold">{error}</p>}

          <button type="submit" disabled={loading}
            className="w-full bg-[#F5C400] text-black font-black text-base py-4 rounded-xl mt-2 disabled:opacity-50 active:scale-95 transition">
            {loading ? "Rejestracja..." : "Zarejestruj się"}
          </button>
        </form>

        <div className="flex items-center justify-center gap-2 mt-6">
          <span className="text-white/40 text-sm">Masz już konto?</span>
          <a href="/login" className="text-[#F5C400] font-bold text-sm">Zaloguj się</a>
        </div>
      </div>
    </div>
  );
}
