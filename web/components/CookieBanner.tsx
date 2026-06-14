"use client";
import { useEffect, useState } from "react";
import { X, Cookie } from "lucide-react";

export default function CookieBanner() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!localStorage.getItem("cookies_accepted")) {
      setVisible(true);
    }
  }, []);

  function accept() {
    localStorage.setItem("cookies_accepted", "1");
    setVisible(false);
  }

  if (!visible) return null;

  return (
    <div className="fixed bottom-20 left-3 right-3 z-50 slide-up sm:bottom-6 sm:left-auto sm:right-6 sm:max-w-sm">
      <div className="bg-[#161616] border border-white/[0.12] rounded-2xl p-4 shadow-[0_8px_40px_rgba(0,0,0,0.6)]">
        <div className="flex items-start gap-3">
          <div className="w-9 h-9 rounded-xl bg-[#F5C400]/10 flex items-center justify-center flex-shrink-0 mt-0.5">
            <Cookie size={18} className="text-[#F5C400]" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-white font-black text-sm mb-1">Używamy plików cookie</p>
            <p className="text-white/40 text-xs leading-relaxed">
              Typerly korzysta z cookies do obsługi konta i reklam Google AdSense.
              Klikając „Rozumiem" akceptujesz naszą{" "}
              <a href="/privacy" className="text-[#F5C400] underline underline-offset-2">politykę prywatności</a>
              {" "}i{" "}
              <a href="/terms" className="text-[#F5C400] underline underline-offset-2">regulamin</a>.
            </p>
          </div>
          <button onClick={accept}
            className="w-7 h-7 rounded-full bg-white/[0.06] flex items-center justify-center flex-shrink-0 active:scale-90 transition">
            <X size={13} className="text-white/40" />
          </button>
        </div>
        <button onClick={accept}
          className="w-full mt-3 py-2.5 rounded-xl bg-[#F5C400] text-black font-black text-sm active:scale-[0.97] transition">
          Rozumiem
        </button>
      </div>
    </div>
  );
}
