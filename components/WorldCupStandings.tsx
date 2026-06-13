"use client";
import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import { supabase, Match } from "@/lib/supabase";
import { computeGroupTables, GroupTable } from "@/lib/worldcup";
import { ChevronLeft, ChevronRight } from "lucide-react";

export default function WorldCupStandings() {
  const [groups, setGroups] = useState<GroupTable[]>([]);
  const [active, setActive] = useState(0);
  const [loading, setLoading] = useState(true);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    supabase.from("matches").select("*").eq("competition", "WC").order("match_time")
      .then(({ data }) => {
        setGroups(computeGroupTables((data ?? []) as Match[]));
        setLoading(false);
      });
  }, []);

  function goTo(idx: number) {
    const clamped = Math.max(0, Math.min(groups.length - 1, idx));
    setActive(clamped);
    const el = scrollRef.current?.children[clamped] as HTMLElement;
    el?.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
  }

  // Synchronizuj aktywną grupę przy ręcznym przewijaniu
  function onScroll() {
    const el = scrollRef.current;
    if (!el) return;
    const idx = Math.round(el.scrollLeft / el.clientWidth);
    if (idx !== active) setActive(idx);
  }

  if (loading) {
    return <div className="skeleton h-80 rounded-2xl" />;
  }

  if (groups.length === 0) {
    return (
      <div className="text-center py-16">
        <p className="text-4xl mb-3">🏆</p>
        <p className="text-white/30 font-semibold">Brak danych tabeli MŚ</p>
      </div>
    );
  }

  return (
    <div className="fade-in">
      {/* Nawigacja grup */}
      <div className="flex items-center justify-between mb-4">
        <button onClick={() => goTo(active - 1)} disabled={active === 0}
          className="w-9 h-9 rounded-full bg-[#111] border border-white/[0.06] flex items-center justify-center text-white/60 disabled:opacity-20 active:scale-90 transition">
          <ChevronLeft size={18} />
        </button>

        <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide px-2">
          {groups.map((g, i) => (
            <button key={g.letter} onClick={() => goTo(i)}
              className={`flex-shrink-0 w-9 h-9 rounded-full font-black text-sm transition-all ${
                i === active ? "bg-[#F5C400] text-black" : "bg-[#111] border border-white/[0.06] text-white/40"
              }`}>
              {g.letter}
            </button>
          ))}
        </div>

        <button onClick={() => goTo(active + 1)} disabled={active === groups.length - 1}
          className="w-9 h-9 rounded-full bg-[#111] border border-white/[0.06] flex items-center justify-center text-white/60 disabled:opacity-20 active:scale-90 transition">
          <ChevronRight size={18} />
        </button>
      </div>

      {/* Przesuwane tabele */}
      <div ref={scrollRef} onScroll={onScroll}
        className="flex overflow-x-auto snap-x snap-mandatory scrollbar-hide -mx-4 px-4 gap-4">
        {groups.map(g => (
          <div key={g.letter} className="flex-shrink-0 w-full snap-center">
            <GroupCard group={g} />
          </div>
        ))}
      </div>

      <p className="text-center text-white/20 text-[11px] mt-3">
        Przesuń palcem lub użyj strzałek · 3 pkt zwycięstwo · 1 pkt remis
      </p>
    </div>
  );
}

function GroupCard({ group }: { group: GroupTable }) {
  return (
    <div className="bg-[#111] border border-white/[0.06] rounded-2xl overflow-hidden">
      {/* Nagłówek grupy */}
      <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-r from-[#1a1500] to-transparent border-b border-white/[0.06]">
        <span className="w-7 h-7 rounded-lg bg-[#F5C400] text-black font-black text-sm flex items-center justify-center">{group.letter}</span>
        <span className="text-white font-black text-sm uppercase tracking-wide">Grupa {group.letter}</span>
      </div>

      {/* Nagłówki kolumn */}
      <div className="flex items-center px-3 py-2 text-white/30 text-[10px] font-bold uppercase border-b border-white/[0.04]">
        <span className="w-6 text-center">#</span>
        <span className="flex-1 pl-1">Drużyna</span>
        <span className="w-6 text-center">M</span>
        <span className="w-6 text-center block">Z</span>
        <span className="w-6 text-center block">R</span>
        <span className="w-6 text-center block">P</span>
        <span className="w-9 text-center">+/-</span>
        <span className="w-8 text-center text-[#F5C400]">Pkt</span>
      </div>

      {/* Wiersze */}
      {group.rows.map((r, i) => (
        <div key={r.team}
          className={`flex items-center px-3 py-2.5 ${i < group.rows.length - 1 ? "border-b border-white/[0.03]" : ""} ${
            i < 2 ? "bg-green-500/[0.04]" : ""
          }`}>
          {/* Pozycja - top 2 awansują (zielony) */}
          <span className={`w-6 text-center font-black text-sm ${i < 2 ? "text-green-400" : "text-white/30"}`}>
            {i + 1}
          </span>
          {/* Drużyna */}
          <div className="flex-1 flex items-center gap-2 pl-1 min-w-0">
            {r.logo ? (
              <Image src={r.logo} alt={r.team} width={20} height={20} className="object-contain flex-shrink-0" unoptimized />
            ) : (
              <span className="w-5 h-5 rounded-full bg-white/10 flex items-center justify-center text-[9px] font-black flex-shrink-0">{r.team[0]}</span>
            )}
            <span className="text-white font-semibold text-xs truncate">{r.team}</span>
          </div>
          <span className="w-6 text-center text-white/60 text-xs tabular-nums">{r.played}</span>
          <span className="w-6 text-center text-white/40 text-xs tabular-nums block">{r.won}</span>
          <span className="w-6 text-center text-white/40 text-xs tabular-nums block">{r.draw}</span>
          <span className="w-6 text-center text-white/40 text-xs tabular-nums block">{r.lost}</span>
          <span className={`w-9 text-center text-xs tabular-nums font-semibold ${r.goalDiff > 0 ? "text-green-400/70" : r.goalDiff < 0 ? "text-red-400/70" : "text-white/40"}`}>
            {r.goalDiff > 0 ? "+" : ""}{r.goalDiff}
          </span>
          <span className="w-8 text-center text-[#F5C400] font-black text-sm tabular-nums">{r.points}</span>
        </div>
      ))}
    </div>
  );
}
