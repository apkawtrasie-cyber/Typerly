"use client";
import { useEffect, useRef } from "react";
import dynamic from "next/dynamic";
import confetti from "canvas-confetti";
import { pointsLabel, badgeFor } from "@/lib/scorer";
import gwiazdaData from "@/public/lottie/gwiazda.json";
import tarczaData from "@/public/lottie/tarcza.json";

// Lottie ładowany tylko po stronie klienta (brak SSR)
const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

type Props = {
  username: string;
  points: number;
  predictedHome: number;
  predictedAway: number;
  actualHome: number;
  actualAway: number;
  onClose: () => void;
  onCheck: () => void;
};

const RARITY_COLOR: Record<string, string> = {
  legendary: "#FF9500", epic: "#AA44FF", rare: "#44AAFF", common: "#88CC88",
};
const RARITY_LABEL: Record<string, string> = {
  legendary: "LEGENDARNY", epic: "EPICKI", rare: "RZADKI", common: "ZWYKŁY",
};

function accentColor(points: number): string {
  switch (points) {
    case 3: return "#F5C400";
    case 2: return "#44AAFF";
    case 1: return "#66DD66";
    default: return "#FF4444";
  }
}

export default function PredictionResultOverlay({
  username, points, predictedHome, predictedAway, actualHome, actualAway, onClose, onCheck,
}: Props) {
  const won = points > 0;
  const accent = accentColor(points);
  const badge = badgeFor(points);
  const badgeColor = RARITY_COLOR[badge.rarity];
  const closed = useRef(false);

  useEffect(() => {
    const colors = won
      ? ["#F5C400", "#ffffff", "#44AAFF", "#00E676", "#FF66CC"]
      : ["#FF4444", "#ffffff", "#FF9500", "#AA44FF"];

    const duration = won ? 4000 : 3000;
    const end = Date.now() + duration;

    confetti({
      particleCount: won ? 160 : 100,
      spread: 100,
      origin: { y: 0.5 },
      colors,
      scalar: 1.1,
      shapes: ["star", "circle"],
    });

    const interval = setInterval(() => {
      if (Date.now() > end) { clearInterval(interval); return; }
      confetti({ particleCount: won ? 12 : 8, angle: 60, spread: 55, origin: { x: 0, y: 0.6 }, colors, shapes: ["star", "circle"] });
      confetti({ particleCount: won ? 12 : 8, angle: 120, spread: 55, origin: { x: 1, y: 0.6 }, colors, shapes: ["star", "circle"] });
    }, 200);

    return () => { clearInterval(interval); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function handleClose() {
    if (closed.current) return;
    closed.current = true;
    onClose();
  }

  function handleCheck() {
    if (closed.current) return;
    closed.current = true;
    onCheck();
  }

  return (
    <div
      onClick={handleClose}
      className="fixed inset-0 z-[100] flex flex-col items-center justify-center px-6"
      style={{ background: "rgba(0,0,0,0.85)", backdropFilter: "blur(4px)" }}
    >
      {won ? (
        /* ===== WYGRANA: animacja gwiazdy Lottie + punkty ===== */
        <div className="flex flex-col items-center fade-in">
          <div
            className="w-44 h-44 mb-0"
            style={{ filter: `drop-shadow(0 0 30px ${accent}80)` }}
          >
            <Lottie animationData={gwiazdaData} loop={false} />
          </div>

          <p className="font-black text-3xl font-archivo mb-3" style={{ color: accent }}>
            {username}
          </p>

          <div
            className="rounded-2xl px-7 py-3 text-center mb-4"
            style={{ backgroundColor: accent + "26", border: `1.5px solid ${accent}99` }}
          >
            <p className="font-black text-4xl font-archivo leading-none" style={{ color: accent }}>
              +{points} {points === 1 ? "punkt" : "punkty"}
            </p>
            <p className="text-white/70 text-xs font-bold tracking-widest mt-1">{pointsLabel(points)}</p>
          </div>

          <p className="text-white/40 text-xs mb-5">
            Twój typ: {predictedHome}:{predictedAway} &nbsp;•&nbsp; Wynik: {actualHome}:{actualAway}
          </p>

          <BadgeChip name={`${badge.name} ${badge.icon}`} rarity={badge.rarity} color={badgeColor} subtitle="Zdobywasz odznakę!" />
        </div>
      ) : (
        /* ===== PUDŁO: animacja tarczy Lottie ===== */
        <div className="flex flex-col items-center fade-in">
          <div
            className="w-40 h-40 mb-1"
            style={{ filter: `drop-shadow(0 0 25px ${badgeColor}80)`, animation: "slide-up 0.6s ease" }}
          >
            <Lottie animationData={tarczaData} loop={false} />
          </div>

          <p className="font-black text-2xl font-archivo text-white/80 mb-3">{username}</p>

          <div className="rounded-2xl px-6 py-4 text-center mb-4 max-w-xs" style={{ backgroundColor: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.12)" }}>
            <p className="text-white/80 text-base font-bold mb-1">Nie tym razem — ale odznaka za udział! 🛡️</p>
            <p className="text-white/40 text-xs mb-2">Każdy typ to krok do mistrzostwa 🚀</p>
            <p className="text-white/25 text-[11px]">
              Twój typ: {predictedHome}:{predictedAway} &nbsp;•&nbsp; Wynik: {actualHome}:{actualAway}
            </p>
          </div>

          <BadgeChip name={`${badge.name} ${badge.icon}`} rarity={badge.rarity} color={badgeColor} subtitle="Zdobywasz odznakę!" />
        </div>
      )}

      {/* Przycisk na dole ekranu */}
      <div
        className="absolute left-0 right-0 px-6"
        style={{ bottom: "calc(2rem + env(safe-area-inset-bottom))" }}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={handleCheck}
          className="w-full font-black text-black text-lg py-4 rounded-2xl active:scale-95 transition"
          style={{ backgroundColor: accent, boxShadow: `0 6px 24px ${accent}66` }}
        >
          Sprawdź
        </button>
        <button onClick={handleClose} className="w-full text-white/40 text-sm font-semibold py-3 mt-1">
          Zamknij
        </button>
      </div>
    </div>
  );
}

function BadgeChip({ name, rarity, color, subtitle }: { name: string; rarity: string; color: string; subtitle?: string }) {
  return (
    <div className="flex flex-col items-center" style={{ animation: "slide-up 0.5s ease 0.2s both" }}>
      {subtitle && (
        <p className="font-black text-sm tracking-wider mb-2" style={{ color }}>{subtitle}</p>
      )}
      <div
        className="flex items-center gap-2 px-5 py-2.5 rounded-full"
        style={{ backgroundColor: color + "1F", border: `1.5px solid ${color}B3`, boxShadow: `0 0 18px ${color}59` }}
      >
        <span className="font-black text-sm" style={{ color }}>{name}</span>
        <span className="text-[9px] font-black px-1.5 py-0.5 rounded tracking-wider" style={{ color, backgroundColor: color + "33" }}>
          {RARITY_LABEL[rarity]}
        </span>
      </div>
    </div>
  );
}
