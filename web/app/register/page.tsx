"use client";
export const dynamic = 'force-dynamic';
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase, generateUniqueUsername } from "@/lib/supabase";
import Image from "next/image";
import GoogleAuthButton from "@/components/GoogleAuthButton";
import { useLang } from "@/contexts/LangContext";
import { LOCALES, Locale } from "@/lib/translations";

export default function RegisterPage() {
  const router = useRouter();
  const { t, locale, setLocale } = useLang();
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
      email, password,
      options: { data: { username } },
    });
    setLoading(false);
    if (error) { setError(error.message); return; }
    if (data.session && data.user) {
      // Nadaj nickowi unikalność — zapobiega podszywaniu i duplikatom
      const uniqueName = await generateUniqueUsername(username, data.user.id);
      await supabase.from("profiles").upsert(
        { id: data.user.id, username: uniqueName, is_premium: false },
        { onConflict: "id" },
      );
    }
    setSuccess(true);
  }

  if (success) return (
    <div className="min-h-[100dvh] bg-[#0A0A0A] flex flex-col items-center justify-center px-6 py-10 text-center">
      <div className="text-5xl mb-4">✉️</div>
      <h2 className="text-white font-black text-2xl mb-2">{t("auth.check_email")}</h2>
      <p className="text-white/50 text-sm mb-8">{t("auth.confirm_sent")} <strong className="text-white">{email}</strong></p>
      <a href="/login" className="text-[#F5C400] font-bold">{t("auth.back_to_login")}</a>
    </div>
  );

  return (
    <div className="min-h-[100dvh] bg-[#0A0A0A] flex flex-col items-center px-6 py-10 overflow-y-auto">
      <div className="w-full max-w-sm m-auto">
        <div className="flex flex-col items-center mb-10">
          <div className="relative mb-5">
            <div className="absolute inset-0 rounded-full bg-[#F5C400] opacity-30 blur-2xl scale-110" />
            <Image src="/icons/icon-512.png" alt="Typerly" width={90} height={90} className="relative rounded-full" />
          </div>
          <h1 className="font-archivo font-black text-4xl tracking-widest">
            <span className="text-white">TYPE</span><span className="text-[#F5C400]">RLY</span>
          </h1>
          <p className="text-white/30 text-[10px] font-bold tracking-[3px] mt-1">{t("auth.join_tagline")}</p>
        </div>

        <form onSubmit={handleRegister} className="flex flex-col gap-4">
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">{t("auth.username")}</label>
            <input type="text" value={username} onChange={e => setUsername(e.target.value)}
              placeholder={t("auth.username_placeholder")} required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition" />
          </div>
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">{t("auth.email")}</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)}
              placeholder={t("auth.email_placeholder")} required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition" />
          </div>
          <div>
            <label className="text-white/50 text-xs font-semibold uppercase tracking-wider mb-1 block">{t("auth.password")}</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)}
              placeholder={t("auth.password_min")} required minLength={6}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/50 transition" />
          </div>

          {error && <p className="text-red-400 text-sm text-center font-semibold">{error}</p>}

          <button type="submit" disabled={loading}
            className="w-full bg-[#F5C400] text-black font-black text-base py-4 rounded-xl mt-2 disabled:opacity-50 active:scale-95 transition">
            {loading ? t("auth.registering") : t("auth.register")}
          </button>
        </form>

        <div className="flex items-center gap-3 mt-6 mb-4">
          <div className="flex-1 h-px bg-white/10" />
          <span className="text-white/25 text-xs font-semibold">{t("auth.or")}</span>
          <div className="flex-1 h-px bg-white/10" />
        </div>
        <GoogleAuthButton mode="register" />

        <div className="flex items-center justify-center gap-2 mt-6">
          <span className="text-white/40 text-sm">{t("auth.have_account")}</span>
          <a href="/login" className="text-[#F5C400] font-bold text-sm">{t("auth.login")}</a>
        </div>
      </div>

      {/* Przełącznik języka — dół ekranu */}
      <div className="flex justify-center pt-8 pb-2">
        <div className="flex items-center gap-1 bg-white/5 border border-white/10 rounded-xl p-1">
          {LOCALES.map(loc => (
            <button
              key={loc.code}
              onClick={() => setLocale(loc.code as Locale)}
              title={loc.nativeName}
              className={`px-2 py-1 rounded-lg text-sm transition ${locale === loc.code ? "bg-[#F5C400] text-black font-bold" : "text-white/40 hover:text-white/70"}`}
            >
              {loc.flag}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
