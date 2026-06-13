"use client";
import { useEffect, useRef } from "react";
import dynamic from "next/dynamic";
import Image from "next/image";
import confetti from "canvas-confetti";
import { pointsLabel, badgeFor } from "@/lib/scorer";
import gwiazdaData from "@/public/lottie/gwiazda.json";
import tarczaData from "@/public/lottie/tarcza.json";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

type Props = {
  username: string;
  points: number;
  predictedHome: number;
  predictedAway: number;
  actualHome: number;
  actualAway: number;
  homeTeam: string;
  awayTeam: string;
  homeLogo: string | null;
  awayLogo: string | null;
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

function TeamLogo({ url, name }: { url: string | null; name: string }) {
  if (url) {
    return (
      <Image src={url} alt={name} width={36} height={36}
        className="w-9 h-9 object-contain rounded-lg"
        onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
      />
    );
  }
  return (
    <div className="w-9 h-9 rounded-lg bg-white/10 flex items-center justify-center text-white/40 text-xs font-black">
      {name.slice(0, 2).toUpperCase()}
    </div>
  );
}

export default function PredictionResultOverlay({
  username, points,
  predictedHome, predictedAway, actualHome, actualAway,
  homeTeam, awayTeam, homeLogo, awayLogo,
  onClose, onCheck,
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

    confetti({ particleCount: won ? 160 : 100, spread: 100, origin: { y: 0.5 }, colors, scalar: 1.1, shapes: ["star", "circle"] });

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
      style={{ background: "rgba(0,0,0,0.88)", backdropFilter: "blur(6px)" }}
    >
      {won ? (
        /* ===== WYGRANA ===== */
        <div className="flex flex-col items-center fade-in w-full max-w-sm">
          {/* Animacja gwiazdy — 3 powtórzenia */}
          <div className="w-48 h-48 -mb-2" style={{ filter: `drop-shadow(0 0 32px ${accent}90)` }}>
            <Lottie animationData={gwiazdaData} loop={3} />
          </div>

          <p className="font-black text-2xl font-archivo mb-3" style={{ color: accent }}>
            {username}
          </p>

          {/* Punkty */}
          <div
            className="rounded-2xl px-7 py-3 text-center mb-4 w-full"
            style={{ backgroundColor: accent + "20", border: `1.5px solid ${accent}99` }}
          >
            <p className="font-black text-4xl font-archivo leading-none" style={{ color: accent }}>
              +{points} {points === 1 ? "punkt" : "punkty"}
            </p>
            <p className="text-white/60 text-xs font-bold tracking-widest mt-1">{pointsLabel(points)}</p>
          </div>

          {/* Karta meczu */}
          <MatchCard
            homeTeam={homeTeam} awayTeam={awayTeam}
            homeLogo={homeLogo} awayLogo={awayLogo}
            predictedHome={predictedHome} predictedAway={predictedAway}
            actualHome={actualHome} actualAway={actualAway}
            accent={accent}
          />

          <BadgeChip name={`${badge.name} ${badge.icon}`} rarity={badge.rarity} color={badgeColor} subtitle="Zdobywasz odznakę!" />
        </div>
      ) : (
        /* ===== PUDŁO ===== */
        <div className="flex flex-col items-center fade-in w-full max-w-sm">
          <div className="w-40 h-40 mb-1" style={{ filter: `drop-shadow(0 0 25px ${badgeColor}80)`, animation: "slide-up 0.6s ease" }}>
            <Lottie animationData={tarczaData} loop={false} />
          </div>

          <p className="font-black text-2xl font-archivo text-white/80 mb-3">{username}</p>

          <div className="rounded-2xl px-5 py-3 text-center mb-3 w-full" style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)" }}>
            <p className="text-white/70 text-sm font-bold mb-2">Nie tym razem — ale odznaka za udział! 🛡️</p>
            <p className="text-white/35 text-xs">Każdy typ to krok do mistrzostwa 🚀</p>
          </div>

          {/* Karta meczu */}
          <MatchCard
            homeTeam={homeTeam} awayTeam={awayTeam}
            homeLogo={homeLogo} awayLogo={awayLogo}
            predictedHome={predictedHome} predictedAway={predictedAway}
            actualHome={actualHome} actualAway={actualAway}
            accent={accent}
          />

          <BadgeChip name={`${badge.name} ${badge.icon}`} rarity={badge.rarity} color={badgeColor} subtitle="Zdobywasz odznakę!" />
        </div>
      )}

      {/* Przyciski na dole */}
      <div
        className="absolute left-0 right-0 px-6"
        style={{ bottom: "calc(2rem + env(safe-area-inset-bottom))" }}
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={handleCheck}
          className="w-full font-black text-black text-lg py-4 rounded-2xl active:scale-95 transition"
          style={{ backgroundColor: accent, boxShadow: `0 6px 24px ${accent}55` }}
        >
          Sprawdź wyniki
        </button>
        <button onClick={handleClose} className="w-full text-white/35 text-sm font-semibold py-3 mt-1">
          Zamknij
        </button>
      </div>
    </div>
  );
}

/* Karta pokazująca mecz: logo + nazwa drużyny, typ vs wynik */
function MatchCard({
  homeTeam, awayTeam, homeLogo, awayLogo,
  predictedHome, predictedAway, actualHome, actualAway, accent,
}: {
  homeTeam: string; awayTeam: string;
  homeLogo: string | null; awayLogo: string | null;
  predictedHome: number; predictedAway: number;
  actualHome: number; actualAway: number;
  accent: string;
}) {
  return (
    <div
      className="w-full rounded-2xl px-4 py-4 mb-4"
      style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.09)" }}
    >
      {/* Drużyny */}
      <div className="flex items-center justify-between gap-2 mb-3">
        <div className="flex flex-col items-center gap-1.5 flex-1">
          <TeamLogo url={homeLogo} name={homeTeam} />
          <span className="text-white/70 text-[11px] font-semibold text-center leading-tight line-clamp-2">{homeTeam}</span>
        </div>

        <div className="flex flex-col items-center gap-1 px-2">
          {/* Wynik rzeczywisty */}
          <span className="text-white font-black text-2xl tabular-nums tracking-tight">
            {actualHome}:{actualAway}
          </span>
          <span className="text-white/25 text-[9px] font-bold uppercase tracking-wider">Wynik</span>
        </div>

        <div className="flex flex-col items-center gap-1.5 flex-1">
          <TeamLogo url={awayLogo} name={awayTeam} />
          <span className="text-white/70 text-[11px] font-semibold text-center leading-tight line-clamp-2">{awayTeam}</span>
        </div>
      </div>

      {/* Separator */}
      <div className="h-px bg-white/[0.07] mb-3" />

      {/* Mój typ */}
      <div className="flex items-center justify-between">
        <span className="text-white/40 text-[11px] font-semibold">Twój typ</span>
        <span className="font-black tabular-nums text-base" style={{ color: accent }}>
          {predictedHome}:{predictedAway}
        </span>
      </div>
    </div>
  );
}

function BadgeChip({ name, rarity, color, subtitle }: { name: string; rarity: string; color: string; subtitle?: string }) {
  return (
    <div className="flex flex-col items-center" style={{ animation: "slide-up 0.5s ease 0.2s both" }}>
      {subtitle && (
        <p className="font-black text-xs tracking-wider mb-2" style={{ color }}>{subtitle}</p>
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
