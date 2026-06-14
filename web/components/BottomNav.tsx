"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Trophy, Users, MessageCircle, User } from "lucide-react";
import { useLang } from "@/contexts/LangContext";

export default function BottomNav() {
  const pathname = usePathname();
  const { t } = useLang();

  const tabs = [
    { href: "/home",    icon: Home,          label: t("nav.home") },
    { href: "/matches", icon: Trophy,         label: t("nav.matches") },
    { href: "/leagues", icon: Users,          label: t("nav.leagues") },
    { href: "/chat",    icon: MessageCircle,  label: t("nav.chat") },
    { href: "/profile", icon: User,           label: t("nav.profile") },
  ];

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-50"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <div className="bg-[#0D0D0D]/95 backdrop-blur-xl border-t border-white/[0.12] flex items-stretch justify-around px-1">
        {tabs.map(({ href, icon: Icon, label }) => {
          const active = pathname === href || pathname.startsWith(href + "/");
          return (
            <Link
              key={href}
              href={href}
              className={`relative flex flex-col items-center justify-center gap-1 py-3 px-4 flex-1 transition-all duration-200 ${active ? "text-[#F5C400]" : "text-white/30 hover:text-white/60"}`}
            >
              {active && (
                <span className="absolute top-0 left-1/2 -translate-x-1/2 w-6 h-0.5 bg-[#F5C400] rounded-full" />
              )}
              <Icon size={21} strokeWidth={active ? 2.5 : 1.8} />
              <span className="text-[9px] font-bold tracking-wide uppercase">{label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
