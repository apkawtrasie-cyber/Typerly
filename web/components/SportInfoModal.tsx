"use client";
import { X } from "lucide-react";

export type SportInfo = {
  emoji: string;
  title: string;
  howTo: string;
  rules: { icon: string; text: string }[];
  example?: { home: string; away: string; score: string; explanation: string };
};

export const SPORT_INFO: Record<string, SportInfo> = {
  football: {
    emoji: "⚽",
    title: "Piłka nożna",
    howTo: "Podaj liczbę goli dla każdej drużyny po 90 minutach gry (bez dogrywki).",
    rules: [
      { icon: "⏱️", text: "Mecz trwa 2 × 45 minut = 90 minut" },
      { icon: "🏆", text: "Liczy się wynik po 90 min (bez dogrywki i karnych)" },
      { icon: "🎯", text: "Dokładny wynik = 3 pkt, trafiony typ (1/X/2) = 1 pkt" },
    ],
    example: { home: "Polska", away: "Niemcy", score: "2 : 1", explanation: "Polska wygrywa 2 golami do 1" },
  },
  volleyball: {
    emoji: "🏐",
    title: "Siatkówka",
    howTo: "Podaj liczbę wygranych setów przez każdą drużynę. Mecz to maksymalnie 5 setów.",
    rules: [
      { icon: "🔢", text: "Mecz trwa do 3 wygranych setów (best of 5)" },
      { icon: "✅", text: "Możliwe wyniki: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
      { icon: "📊", text: "Wpisz wynik setów, np. 3:1 = gospodarz wygrywa 3 sety do 1" },
      { icon: "🎯", text: "Dokładny wynik = 3 pkt, trafiony zwycięzca = 1 pkt" },
    ],
    example: { home: "Polska", away: "Brazylia", score: "3 : 1", explanation: "Polska wygrywa 3 sety do 1 (np. 25:20, 20:25, 25:22, 25:18)" },
  },
  handball: {
    emoji: "🤾",
    title: "Piłka ręczna",
    howTo: "Podaj liczbę bramek dla każdej drużyny po 60 minutach gry.",
    rules: [
      { icon: "⏱️", text: "Mecz trwa 2 × 30 minut = 60 minut" },
      { icon: "🥅", text: "Wyniki zwykle w przedziale 20–35 bramek na drużynę" },
      { icon: "📊", text: "Typujesz jak w piłce nożnej — wpisujesz bramki" },
      { icon: "🎯", text: "Dokładny wynik = 3 pkt, trafiony typ (1/X/2) = 1 pkt" },
    ],
    example: { home: "Polska", away: "Francja", score: "28 : 24", explanation: "Polska wygrywa 28 bramkami do 24" },
  },
  f1: {
    emoji: "🏎️",
    title: "Formuła 1",
    howTo: "Przeglądaj kalendarz wyścigów, wyniki i tabelę kierowców. Typowanie wyścigów F1 już wkrótce!",
    rules: [
      { icon: "📅", text: "Kalendarz — wszystkie wyścigi sezonu 2026" },
      { icon: "🏁", text: "Wyniki — podium każdego Grand Prix" },
      { icon: "🏆", text: "Tabela — klasyfikacja kierowców z punktami" },
      { icon: "🔜", text: "Typowanie wyścigów (kto wygra GP) — wkrótce" },
    ],
  },
};

interface Props {
  sport: string;
  onClose: () => void;
}

export default function SportInfoModal({ sport, onClose }: Props) {
  const info = SPORT_INFO[sport];
  if (!info) return null;

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 z-[80] bg-black/70 backdrop-blur-sm flex items-end fade-in"
    >
      <div
        onClick={e => e.stopPropagation()}
        className="w-full bg-[#141414] border-t border-white/10 rounded-t-3xl pb-safe slide-up max-h-[85vh] overflow-y-auto"
      >
        {/* Handle */}
        <div className="flex justify-center pt-3 pb-1">
          <span className="w-10 h-1 rounded-full bg-white/15" />
        </div>

        <div className="px-5 pt-2 pb-6">
          {/* Nagłówek */}
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <span className="text-4xl leading-none">{info.emoji}</span>
              <div>
                <h2 className="text-white font-black text-lg">{info.title}</h2>
                <p className="text-white/30 text-xs">Jak typować?</p>
              </div>
            </div>
            <button onClick={onClose} className="w-8 h-8 rounded-full bg-white/[0.06] flex items-center justify-center">
              <X size={16} className="text-white/50" />
            </button>
          </div>

          {/* Opis */}
          <div className="bg-[#F5C400]/[0.08] border border-[#F5C400]/20 rounded-2xl px-4 py-3 mb-4">
            <p className="text-white/80 text-sm leading-relaxed">{info.howTo}</p>
          </div>

          {/* Zasady */}
          <div className="flex flex-col gap-2 mb-4">
            {info.rules.map((r, i) => (
              <div key={i} className="flex items-start gap-3 bg-[#1e1e1e] border border-white/[0.12] rounded-xl px-3 py-2.5">
                <span className="text-lg leading-none flex-shrink-0 mt-0.5">{r.icon}</span>
                <p className="text-white/70 text-sm">{r.text}</p>
              </div>
            ))}
          </div>

          {/* Przykład */}
          {info.example && (
            <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl p-4">
              <p className="text-white/30 text-[10px] font-black uppercase tracking-widest mb-3">Przykład</p>
              <div className="flex items-center justify-between gap-2 mb-2">
                <span className="text-white font-semibold text-sm flex-1">{info.example.home}</span>
                <span className="text-[#F5C400] font-black text-xl tabular-nums px-3">{info.example.score}</span>
                <span className="text-white font-semibold text-sm flex-1 text-right">{info.example.away}</span>
              </div>
              <p className="text-white/40 text-xs text-center">{info.example.explanation}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
