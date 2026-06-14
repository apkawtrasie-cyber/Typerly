"use client";
import { useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabase";

const ADSENSE_CLIENT = "ca-pub-5244367621175515";

// Globalny cache statusu premium, żeby nie odpytywać bazy przy każdym banerze
let premiumCache: boolean | null = null;

declare global {
  interface Window {
    adsbygoogle?: unknown[];
  }
}

type Props = {
  /** ID jednostki reklamowej z panelu AdSense (data-ad-slot). */
  slot: string;
  /** Format reklamy AdSense (domyślnie auto/responsywny). */
  format?: string;
  /** Dodatkowe klasy kontenera. */
  className?: string;
};

/**
 * Responsywny baner AdSense.
 * - Chowa się automatycznie dla użytkowników premium (is_premium).
 * - Nie renderuje nic, dopóki nie poznamy statusu premium (brak migotania).
 * - Wymaga utworzenia jednostki reklamowej w panelu AdSense i podania jej `slot`.
 */
export default function AdBanner({ slot, format = "auto", className = "" }: Props) {
  const [premium, setPremium] = useState<boolean | null>(premiumCache);
  const insRef = useRef<HTMLModElement>(null);
  const pushed = useRef(false);

  useEffect(() => {
    if (premiumCache !== null) { setPremium(premiumCache); return; }
    let active = true;
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { premiumCache = false; if (active) setPremium(false); return; }
      const { data } = await supabase.from("profiles").select("is_premium").eq("id", user.id).maybeSingle();
      premiumCache = data?.is_premium ?? false;
      if (active) setPremium(premiumCache);
    })();
    return () => { active = false; };
  }, []);

  useEffect(() => {
    if (premium === false && !pushed.current && insRef.current) {
      try {
        (window.adsbygoogle = window.adsbygoogle || []).push({});
        pushed.current = true;
      } catch { /* skrypt jeszcze się nie załadował — pominie się */ }
    }
  }, [premium]);

  // Premium albo jeszcze nie wiemy → nic nie pokazujemy
  if (premium !== false) return null;

  return (
    <div className={`w-full overflow-hidden ${className}`}>
      <ins
        ref={insRef}
        className="adsbygoogle"
        style={{ display: "block" }}
        data-ad-client={ADSENSE_CLIENT}
        data-ad-slot={slot}
        data-ad-format={format}
        data-full-width-responsive="true"
      />
    </div>
  );
}
