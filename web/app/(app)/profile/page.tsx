"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { LogOut, ChevronRight, Mail, Lock, Globe } from "lucide-react";
import { useLang } from "@/contexts/LangContext";
import { LOCALES, Locale, TranslationKey } from "@/lib/translations";

type Profile = { id: string; username: string; avatar_url: string | null };
type BadgeDef = { name: string; icon: string; rarity: string };
type Badge = { badge_id: string; awarded_at: string; badge_definitions: BadgeDef | BadgeDef[] };
type Pred = { points_earned: number | null; is_calculated: boolean; updated_at: string };

// Statystyki liczone bezpośrednio z typów (jak w aplikacji Flutter)
type Stats = {
  totalPoints: number;
  weekPoints: number;
  totalPredictions: number;
  calculated: number;
  exact: number;     // 3 pkt — dokładny wynik
  diff: number;      // 2 pkt — różnica bramek
  tendency: number;  // 1 pkt — tendencja
  miss: number;      // 0 pkt — pudło
  accuracy: number;  // % trafień (pts>0)
  streak: number;
};

const RARITY_COLOR: Record<string, string> = { legendary: "#FF9500", epic: "#AA44FF", rare: "#44AAFF", common: "#88CC88" };

function getBadgeDef(b: Badge): BadgeDef | null {
  if (!b.badge_definitions) return null;
  return Array.isArray(b.badge_definitions) ? b.badge_definitions[0] : b.badge_definitions;
}

function StatBox({ value, label, accent }: { value: string | number; label: string; accent?: boolean }) {
  return (
    <div className={`flex-1 rounded-2xl p-4 text-center border ${accent ? "bg-[#1a1500] border-[#F5C400]/20" : "bg-[#1e1e1e] border-white/[0.12]"}`}>
      <p className={`font-black text-2xl font-archivo ${accent ? "text-[#F5C400]" : "text-white"}`}>{value}</p>
      <p className="text-white/30 text-[10px] font-semibold uppercase tracking-wide mt-1">{label}</p>
    </div>
  );
}

function PointsRow({ icon, label, sub, count, pts, color, last }: {
  icon: string; label: string; sub: string; count: number; pts: number; color: string; last?: boolean;
}) {
  return (
    <div className={`flex items-center px-4 py-3 ${last ? "" : "border-b border-white/[0.04]"}`}>
      <span className="text-xl w-8">{icon}</span>
      <div className="flex-1">
        <p className="text-white font-semibold text-sm">{label}</p>
        <p className="text-white/30 text-[10px]">{sub}</p>
      </div>
      {/* Liczba typów */}
      <span className="text-white/50 text-sm font-bold mr-4 tabular-nums">×{count}</span>
      {/* Wkład w punkty */}
      <span className="font-black text-sm tabular-nums w-14 text-right" style={{ color: pts > 0 ? color : "rgba(255,255,255,0.2)" }}>
        {pts > 0 ? `+${pts}` : "0"} pkt
      </span>
    </div>
  );
}

export default function ProfilePage() {
  const router = useRouter();
  const { t, locale, setLocale } = useLang();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [badges, setBadges] = useState<Badge[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [showEmailDialog, setShowEmailDialog] = useState(false);
  const [showPassDialog, setShowPassDialog] = useState(false);
  const [newEmail, setNewEmail] = useState("");
  const [newPass, setNewPass] = useState("");
  const [dialogMsg, setDialogMsg] = useState("");

  useEffect(() => {
    async function load() {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { router.push("/login"); return; }

      const [{ data: p }, { data: b }, { data: preds }] = await Promise.all([
        supabase.from("profiles").select("id, username, avatar_url").eq("id", user.id).single(),
        supabase.from("user_badges").select("badge_id, awarded_at, badge_definitions(name, icon, rarity)").eq("user_id", user.id).order("awarded_at", { ascending: false }),
        supabase.from("predictions").select("points_earned, is_calculated, updated_at").eq("user_id", user.id).order("updated_at", { ascending: false }),
      ]);

      setProfile(p);
      setBadges(b ?? []);

      // Wszystkie statystyki liczone z typów — tak jak w aplikacji Flutter
      const all = (preds ?? []) as Pred[];
      const weekStart = new Date(Date.now() - 7 * 86400000);
      let totalPoints = 0, weekPoints = 0, calculated = 0;
      let exact = 0, diff = 0, tendency = 0, miss = 0, hits = 0;
      let streak = 0, streakBroken = false;

      for (const pred of all) {
        if (!pred.is_calculated) continue;
        calculated++;
        const pts = pred.points_earned ?? 0;
        totalPoints += pts;
        if (pts === 3) exact++;
        else if (pts === 2) diff++;
        else if (pts === 1) tendency++;
        else miss++;
        if (pts > 0) hits++;
        if (pred.updated_at && new Date(pred.updated_at) > weekStart) weekPoints += pts;
        if (!streakBroken) {
          if (pts > 0) streak++;
          else streakBroken = true;
        }
      }

      setStats({
        totalPoints, weekPoints,
        totalPredictions: all.length, calculated,
        exact, diff, tendency, miss,
        accuracy: calculated > 0 ? Math.round((hits / calculated) * 100) : 0,
        streak,
      });
      setLoading(false);
    }
    load();
  }, [router]);

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push("/login");
  }

  async function handleEmailChange() {
    const { error } = await supabase.auth.updateUser({ email: newEmail });
    setDialogMsg(error ? `${t("profile.error_prefix")}: ${error.message}` : t("profile.email_changed"));
  }

  async function handlePassChange() {
    if (newPass.length < 6) { setDialogMsg(t("profile.too_short")); return; }
    const { error } = await supabase.auth.updateUser({ password: newPass });
    setDialogMsg(error ? `${t("profile.error_prefix")}: ${error.message}` : t("profile.pass_changed"));
  }

  if (loading) return (
    <div className="flex justify-center items-center min-h-screen">
      <div className="w-8 h-8 border-2 border-[#F5C400] border-t-transparent rounded-full animate-spin" />
    </div>
  );

  const s = stats!;
  const streak = s.streak;
  // Trofea = dokładne trafienia (3 pkt), gwiazdki = pudła (0 pkt) — liczone z typów
  const trophyCount = s.exact;
  const starCount = s.miss;

  return (
    <div className="px-4 pt-6 pb-6 fade-in">
      {/* Avatar + Nazwa */}
      <div className="flex flex-col items-center mb-6">
        <div className="relative mb-3">
          <div className="absolute inset-0 rounded-full bg-[#F5C400]/20 blur-xl scale-125" />
          <div className="relative w-20 h-20 rounded-full bg-gradient-to-br from-[#F5C400]/20 to-[#F5C400]/5 border-2 border-[#F5C400]/30 flex items-center justify-center text-3xl font-black text-[#F5C400] font-archivo">
            {profile?.username?.[0]?.toUpperCase() ?? "?"}
          </div>
          {streak > 0 && (
            <div className="absolute -bottom-1 -right-1 bg-red-500 rounded-full w-7 h-7 flex items-center justify-center text-white text-[10px] font-black border-2 border-[#080808]">
              🔥
            </div>
          )}
        </div>
        <h1 className="text-white font-black text-2xl font-archivo">{profile?.username}</h1>
        {streak > 0 && (
          <p className="text-red-400 text-xs font-bold mt-1">{streak} {t("profile.streak_suffix")} 🔥</p>
        )}
      </div>

      {/* Statystyki główne */}
      <div className="flex gap-3 mb-3">
        <StatBox value={s.totalPoints} label={t("profile.total_points")} accent />
        <StatBox value={s.totalPredictions} label={t("profile.predictions")} />
        <StatBox value={`${s.accuracy}%`} label={t("profile.accuracy")} />
      </div>

      {/* Druga linia statystyk */}
      <div className="flex gap-3 mb-6">
        <StatBox value={`+${s.weekPoints}`} label={t("profile.week_points")} />
        <StatBox value={s.calculated} label={t("profile.calculated")} />
        <StatBox value={s.streak} label={`${t("profile.streak")} 🔥`} />
      </div>

      {/* Rozbicie punktów */}
      <div className="mb-6">
        <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">{t("profile.stats")}</h2>
        <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl overflow-hidden">
          <PointsRow icon="🎯" label={t("profile.exact")} sub="3 pkt" count={s.exact} pts={s.exact * 3} color="#F5C400" />
          <PointsRow icon="⚡" label={t("profile.diff")} sub="2 pkt" count={s.diff} pts={s.diff * 2} color="#44AAFF" />
          <PointsRow icon="📊" label={t("profile.tendency")} sub="1 pkt" count={s.tendency} pts={s.tendency * 1} color="#66DD66" />
          <PointsRow icon="❌" label={t("profile.miss")} sub="0 pkt" count={s.miss} pts={0} color="#FF4444" last />
          <div className="flex items-center justify-between px-4 py-3 bg-[#1a1500] border-t border-[#F5C400]/20">
            <span className="text-white font-black text-sm uppercase tracking-wide">Total</span>
            <span className="text-[#F5C400] font-black text-lg">{s.totalPoints} {t("home.points")}</span>
          </div>
        </div>
      </div>

      {/* Puchary i gwiazdki */}
      <div className="flex gap-3 mb-6">
        <div className="flex-1 bg-[#1e1e1e] border border-white/[0.12] rounded-2xl p-4 flex items-center gap-3">
          <span className="text-3xl">🏆</span>
          <div>
            <p className="text-white font-black text-xl">{trophyCount}</p>
            <p className="text-white/30 text-xs">{t("profile.trophies")}</p>
          </div>
        </div>
        <div className="flex-1 bg-[#1e1e1e] border border-white/[0.12] rounded-2xl p-4 flex items-center gap-3">
          <span className="text-3xl">⭐</span>
          <div>
            <p className="text-white font-black text-xl">{starCount}</p>
            <p className="text-white/30 text-xs">{t("profile.stars")}</p>
          </div>
        </div>
      </div>

      {/* Odznaki */}
      <div className="mb-6">
        <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">{t("profile.badges")}</h2>
        {badges.length === 0 ? (
          <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl p-6 text-center">
            <p className="text-2xl mb-2">🎯</p>
            <p className="text-white/30 text-sm font-semibold">{t("profile.no_badges")}</p>
          </div>
        ) : (
          <div className="flex flex-wrap gap-2">
            {badges.map(b => {
              const def = getBadgeDef(b);
              const rarity = def?.rarity ?? "common";
              const color = RARITY_COLOR[rarity];
              // Nazwa odznaki tłumaczona po badge_id; fallback do nazwy z bazy
              const badgeKey = `badge.${b.badge_id}` as TranslationKey;
              const badgeName = t(badgeKey) === badgeKey ? (def?.name ?? "") : t(badgeKey);
              return (
                <div key={b.badge_id}
                  style={{ borderColor: color + "50", backgroundColor: color + "12", boxShadow: `0 0 12px ${color}20` }}
                  className="flex items-center gap-2 px-3 py-2 rounded-full border">
                  <span className="text-base">{def?.icon}</span>
                  <span style={{ color }} className="text-xs font-black">{badgeName}</span>
                  <span style={{ color, backgroundColor: color + "25" }} className="text-[8px] font-black px-1.5 py-0.5 rounded">
                    {t(`rarity.${rarity}` as TranslationKey)}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Ustawienia konta */}
      <div className="mb-4">
        <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">{t("profile.settings")}</h2>
        <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl overflow-hidden">
          <button onClick={() => setShowEmailDialog(true)}
            className="w-full flex items-center gap-3 px-4 py-4 border-b border-white/[0.04] active:bg-white/5 transition">
            <Mail size={16} className="text-white/30" />
            <span className="flex-1 text-white/70 text-sm font-semibold text-left">{t("profile.change_email")}</span>
            <ChevronRight size={16} className="text-white/20" />
          </button>
          <button onClick={() => setShowPassDialog(true)}
            className="w-full flex items-center gap-3 px-4 py-4 border-b border-white/[0.04] active:bg-white/5 transition">
            <Lock size={16} className="text-white/30" />
            <span className="flex-1 text-white/70 text-sm font-semibold text-left">{t("profile.change_password")}</span>
            <ChevronRight size={16} className="text-white/20" />
          </button>
          {/* Wybór języka */}
          <div className="px-4 py-4">
            <div className="flex items-center gap-3 mb-3">
              <Globe size={16} className="text-white/30" />
              <span className="flex-1 text-white/70 text-sm font-semibold">{t("profile.current_lang")}</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {LOCALES.map(loc => (
                <button
                  key={loc.code}
                  onClick={() => setLocale(loc.code as Locale)}
                  className={`flex items-center gap-2 px-3 py-2.5 rounded-xl border text-sm font-semibold transition active:scale-95 ${
                    locale === loc.code
                      ? "bg-[#F5C400]/15 border-[#F5C400]/50 text-[#F5C400]"
                      : "bg-white/[0.03] border-white/[0.12] text-white/40 hover:text-white/60"
                  }`}
                >
                  <span className="text-base">{loc.flag}</span>
                  <span className="text-xs">{loc.nativeName}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Wyloguj */}
      <button onClick={handleLogout}
        className="w-full flex items-center justify-center gap-2 border border-red-500/20 text-red-400 font-bold py-3.5 rounded-2xl active:scale-95 transition mb-6">
        <LogOut size={16} />
        {t("profile.logout")}
      </button>

      {/* Linki prawne */}
      <div className="flex items-center justify-center gap-4 mb-6 mt-2">
        <a href="/privacy" className="text-white/25 text-xs underline underline-offset-2 active:text-white/50">
          Polityka prywatności
        </a>
        <span className="text-white/10 text-xs">·</span>
        <a href="/terms" className="text-white/25 text-xs underline underline-offset-2 active:text-white/50">
          Regulamin
        </a>
      </div>

      {/* Dialog - email */}
      {showEmailDialog && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center px-6">
          <div className="bg-[#141414] border border-white/10 rounded-2xl p-6 w-full max-w-sm">
            <h3 className="text-white font-black text-lg mb-4">{t("profile.change_email")}</h3>
            <input value={newEmail} onChange={e => setNewEmail(e.target.value)} type="email" placeholder={t("profile.email_placeholder")}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40 mb-3" />
            {dialogMsg && <p className="text-[#F5C400] text-sm mb-3">{dialogMsg}</p>}
            <div className="flex gap-3">
              <button onClick={() => { setShowEmailDialog(false); setDialogMsg(""); setNewEmail(""); }}
                className="flex-1 border border-white/10 text-white/50 py-3 rounded-xl font-bold">{t("profile.cancel")}</button>
              <button onClick={handleEmailChange} className="flex-1 bg-[#F5C400] text-black font-black py-3 rounded-xl">{t("profile.change")}</button>
            </div>
          </div>
        </div>
      )}

      {/* Dialog - hasło */}
      {showPassDialog && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center px-6">
          <div className="bg-[#141414] border border-white/10 rounded-2xl p-6 w-full max-w-sm">
            <h3 className="text-white font-black text-lg mb-4">{t("profile.change_password")}</h3>
            <input value={newPass} onChange={e => setNewPass(e.target.value)} type="password" placeholder={t("profile.pass_placeholder")}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-[#F5C400]/40 mb-3" />
            {dialogMsg && <p className="text-[#F5C400] text-sm mb-3">{dialogMsg}</p>}
            <div className="flex gap-3">
              <button onClick={() => { setShowPassDialog(false); setDialogMsg(""); setNewPass(""); }}
                className="flex-1 border border-white/10 text-white/50 py-3 rounded-xl font-bold">{t("profile.cancel")}</button>
              <button onClick={handlePassChange} className="flex-1 bg-[#F5C400] text-black font-black py-3 rounded-xl">{t("profile.change")}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
