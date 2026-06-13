"use client";
import { useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { Plus, X, Users, Trophy, LogIn, Share2, MessageCircle } from "lucide-react";
import { useLang } from "@/contexts/LangContext";

const SHARE_URL = "https://typerly.andrzejmich.ch";

export default function TyperlyFab() {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const { t } = useLang();

  const visible = pathname === "/matches" || pathname === "/leagues";
  if (!visible) return null;

  function go(action: string) {
    setOpen(false);
    if (action === "chat") { router.push("/chat"); return; }
    if (pathname === "/leagues") {
      window.dispatchEvent(new CustomEvent("typerly-fab", { detail: action }));
    } else {
      router.push(`/leagues?fab=${action}`);
    }
  }

  async function share() {
    setOpen(false);
    const text = "Typuj wyniki meczów i rywalizuj ze znajomymi w Typerly!";
    try {
      if (navigator.share) {
        await navigator.share({ title: "Typerly", text, url: SHARE_URL });
      } else {
        await navigator.clipboard.writeText(`${text} ${SHARE_URL}`);
        alert("Skopiowano link do schowka!");
      }
    } catch { /* anulowano */ }
  }

  const items = [
    { icon: Users,         label: t("fab.create_league"),      onClick: () => go("create-league") },
    { icon: Trophy,        label: t("fab.create_tournament"),   onClick: () => go("create-tournament") },
    { icon: LogIn,         label: t("fab.join_code"),           onClick: () => go("join") },
    { icon: Share2,        label: t("fab.share_app"),           onClick: share },
    { icon: MessageCircle, label: t("fab.chat"),                onClick: () => go("chat") },
  ];

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        aria-label="Akcje"
        className="fixed right-5 z-40 w-14 h-14 rounded-2xl bg-[#F5C400] text-black flex items-center justify-center shadow-[0_6px_16px_rgba(245,196,0,0.45)] active:scale-90 transition"
        style={{ bottom: "calc(5.5rem + env(safe-area-inset-bottom))" }}
      >
        <Plus size={28} strokeWidth={2.5} />
      </button>

      {open && (
        <div
          onClick={() => setOpen(false)}
          className="fixed inset-0 z-[60] bg-black/70 backdrop-blur-sm flex items-end fade-in"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full bg-[#141414] border-t border-white/10 rounded-t-3xl pb-safe slide-up"
          >
            <div className="flex items-center justify-between px-5 pt-4 pb-2">
              <span className="w-10 h-1 rounded-full bg-white/15 mx-auto" />
              <button onClick={() => setOpen(false)} className="absolute right-5 text-white/40">
                <X size={20} />
              </button>
            </div>
            <div className="px-2 pb-3">
              {items.map(({ icon: Icon, label, onClick }) => (
                <button
                  key={label}
                  onClick={onClick}
                  className="w-full flex items-center gap-4 px-4 py-3.5 rounded-2xl active:bg-white/5 transition"
                >
                  <span className="w-10 h-10 rounded-xl bg-[#F5C400]/12 flex items-center justify-center">
                    <Icon size={20} className="text-[#F5C400]" />
                  </span>
                  <span className="text-white font-semibold">{label}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
