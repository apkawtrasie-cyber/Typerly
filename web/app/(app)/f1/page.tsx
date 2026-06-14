"use client";
export const dynamic = "force-dynamic";
import { useEffect, useState, useCallback } from "react";
import { Flag, Clock, ArrowLeft, Info, ChevronRight } from "lucide-react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import SportInfoModal from "@/components/SportInfoModal";

const ESPN_F1 = "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=2026";
const ESPN_F1_STANDINGS = "https://site.api.espn.com/apis/v2/sports/racing/f1/standings";

type Driver = { name: string; flag: string | null; order: number; team?: string };
type Race = {
  id: string;
  name: string;
  fullName: string;
  date: string;
  state: "pre" | "in" | "post";
  completed: boolean;
  allDrivers: Driver[];
};

type StandingEntry = {
  pos: number;
  name: string;
  team: string;
  flag: string | null;
  points: number;
};

function parseRaces(json: any): Race[] {
  const events: any[] = json?.events ?? [];
  return events.map((e) => {
    const comp = e?.competitions?.[0] ?? {};
    const type = comp?.status?.type ?? {};
    const competitors: any[] = comp?.competitors ?? [];
    const allDrivers: Driver[] = competitors
      .filter((c) => typeof c.order === "number")
      .sort((a, b) => a.order - b.order)
      .map((c) => ({
        name: c?.athlete?.displayName ?? "?",
        flag: c?.athlete?.flag?.href ?? null,
        order: c.order,
        team: c?.team?.shortDisplayName ?? c?.team?.displayName ?? undefined,
      }));
    return {
      id: String(e.id),
      name: e.shortName ?? e.name ?? "Grand Prix",
      fullName: e.name ?? e.shortName ?? "Grand Prix",
      date: e.date,
      state: (type.state ?? "pre") as Race["state"],
      completed: !!type.completed,
      allDrivers,
    };
  });
}

function parseStandings(json: any): StandingEntry[] {
  const entries: any[] = json?.standings?.[0]?.entries ?? json?.children?.[0]?.standings?.entries ?? [];
  return entries.map((e, i) => {
    const stats: any[] = e?.stats ?? [];
    const pts = stats.find((s: any) => s.name === "points" || s.abbreviation === "PTS");
    return {
      pos: i + 1,
      name: e?.athlete?.displayName ?? e?.team?.displayName ?? "?",
      team: e?.team?.shortDisplayName ?? "",
      flag: e?.athlete?.flag?.href ?? null,
      points: pts ? Number(pts.value) : 0,
    };
  });
}

function fmtDate(iso: string) {
  return new Date(iso).toLocaleString("pl-PL", { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" });
}

const MEDAL = ["🥇", "🥈", "🥉"];
const TABS = [
  { key: "upcoming", label: "Nadchodzące" },
  { key: "live", label: "🔴 Na żywo" },
  { key: "finished", label: "Ostatnie" },
  { key: "standings", label: "🏆 Tabela" },
];

function RaceCard({ r, next }: { r: Race; next: boolean }) {
  const finished = r.state === "post";
  const live = r.state === "in";
  const podium = r.allDrivers.slice(0, 3);

  return (
    <Link href={`/f1/${r.id}`} className="block active:scale-[0.98] transition-transform">
      <div className={`rounded-2xl border p-4 ${
        live ? "border-red-500/40 bg-red-500/[0.06] card-glow-live" :
        next ? "border-[#F5C400]/40 bg-[#F5C400]/[0.06] card-glow-gold" :
        "border-white/[0.12] bg-[#1a1a1a] card-glow"
      }`}>
        <div className="flex items-start justify-between gap-3 mb-1">
          <div className="flex items-center gap-2 min-w-0">
            <Flag size={14} className={live ? "text-red-400" : next ? "text-[#F5C400]" : "text-white/30"} />
            <p className="text-white font-black text-sm truncate">{r.name}</p>
          </div>
          <div className="flex items-center gap-2 flex-shrink-0">
            {live && <span className="flex items-center gap-1 text-red-400 text-[10px] font-black"><span className="w-1.5 h-1.5 rounded-full bg-red-400 animate-pulse" />NA ŻYWO</span>}
            {next && !live && <span className="text-[#F5C400] text-[10px] font-black uppercase tracking-wide">Następny</span>}
            <ChevronRight size={14} className="text-white/25" />
          </div>
        </div>
        <p className="text-white/40 text-xs flex items-center gap-1.5 mb-2"><Clock size={11} /> {fmtDate(r.date)}</p>
        {!finished && !live && <p className="text-white/25 text-[10px]">Kliknij aby zobaczyć szczegóły i typować</p>}
        {finished && podium.length > 0 && (
          <div className="flex gap-3 mt-1">
            {podium.map((d) => (
              <div key={d.order} className="flex items-center gap-1.5">
                <span className="text-base leading-none">{MEDAL[d.order - 1]}</span>
                {d.flag && <img src={d.flag} alt="" className="w-4 h-3 object-cover rounded-sm" />}
                <span className="text-white/80 text-xs font-semibold truncate max-w-[70px]">{d.name}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </Link>
  );
}

function StandingsTable({ entries }: { entries: StandingEntry[] }) {
  if (entries.length === 0) {
    return (
      <div className="text-center py-16">
        <p className="text-4xl mb-3">🏎️</p>
        <p className="text-white/30 font-semibold">Tabela niedostępna</p>
      </div>
    );
  }
  return (
    <div className="bg-[#111] border border-white/[0.06] rounded-2xl overflow-hidden card-glow">
      <div className="flex items-center px-3 py-2 text-white/30 text-[10px] font-bold uppercase border-b border-white/[0.04]">
        <span className="w-7 text-center">#</span>
        <span className="flex-1 pl-1">Kierowca</span>
        <span className="w-24 text-right text-white/20 pr-2">Zespół</span>
        <span className="w-12 text-center text-[#F5C400]">PKT</span>
      </div>
      {entries.map((e, i) => (
        <div key={e.name} className={`flex items-center px-3 py-3 gap-1 ${i < entries.length - 1 ? "border-b border-white/[0.03]" : ""}`}>
          <span className={`w-7 text-center font-black text-sm ${i === 0 ? "text-[#F5C400]" : i === 1 ? "text-white/50" : i === 2 ? "text-orange-400/70" : "text-white/25"}`}>
            {i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : e.pos}
          </span>
          <div className="flex-1 flex items-center gap-2 pl-1 min-w-0">
            {e.flag && <img src={e.flag} alt="" className="w-5 h-3.5 object-cover rounded-sm flex-shrink-0" />}
            <div className="min-w-0">
              <p className="text-white font-semibold text-sm truncate">{e.name}</p>
              {e.team && <p className="text-white/30 text-[10px] truncate">{e.team}</p>}
            </div>
          </div>
          <span className="w-12 text-center text-[#F5C400] font-black text-base tabular-nums">{e.points}</span>
        </div>
      ))}
    </div>
  );
}

export default function F1Page() {
  const router = useRouter();
  const [races, setRaces] = useState<Race[]>([]);
  const [standings, setStandings] = useState<StandingEntry[]>([]);
  const [tab, setTab] = useState("upcoming");
  const [loading, setLoading] = useState(true);
  const [standingsLoading, setStandingsLoading] = useState(false);
  const [error, setError] = useState(false);
  const [showInfo, setShowInfo] = useState(false);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetch(ESPN_F1);
        const json = await res.json();
        if (!active) return;
        setRaces(parseRaces(json).sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()));
      } catch {
        if (active) setError(true);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, []);

  useEffect(() => {
    if (tab !== "standings" || standings.length > 0) return;
    setStandingsLoading(true);
    fetch(ESPN_F1_STANDINGS)
      .then(r => r.json())
      .then(json => setStandings(parseStandings(json)))
      .catch(() => {})
      .finally(() => setStandingsLoading(false));
  }, [tab, standings.length]);

  const now = Date.now();
  const liveRaces = races.filter(r => r.state === "in");
  const upcomingRaces = races.filter(r => r.state === "pre");
  const finishedRaces = races.filter(r => r.state === "post").reverse();
  const nextId = upcomingRaces.find(r => new Date(r.date).getTime() >= now)?.id;

  function tabRaces() {
    if (tab === "live") return liveRaces;
    if (tab === "finished") return finishedRaces;
    return upcomingRaces;
  }

  return (
    <div className="px-4 pt-6 pb-nav fade-in">
      <div className="flex items-center gap-3 mb-1">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.06] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <h1 className="text-white font-black text-2xl font-archivo flex-1">🏎️ Formuła 1</h1>
        <button onClick={() => setShowInfo(true)} className="w-9 h-9 rounded-full bg-white/[0.06] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <Info size={18} className="text-white/40" />
        </button>
      </div>
      <p className="text-white/30 text-xs mb-5 pl-12">Sezon 2026 · dane: ESPN · kliknij wyścig po szczegóły</p>
      {showInfo && <SportInfoModal sport="f1" onClose={() => setShowInfo(false)} />}

      <div className="flex gap-2 mb-5 overflow-x-auto scrollbar-hide -mx-4 px-4 pb-1">
        {TABS.map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            className={`relative flex-shrink-0 px-4 py-2 rounded-full text-xs font-black uppercase tracking-wide transition-all ${
              tab === t.key ? "bg-[#F5C400] text-black" : "bg-[#111] border border-white/[0.06] text-white/40"
            }`}>
            {t.label}
            {t.key === "live" && liveRaces.length > 0 && (
              <span className="ml-1.5 bg-red-500 text-white text-[9px] font-black rounded-full px-1.5 py-0.5">{liveRaces.length}</span>
            )}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex flex-col gap-2">{[0,1,2,3].map(i => <div key={i} className="skeleton h-20 rounded-2xl" />)}</div>
      ) : error ? (
        <div className="text-center py-16">
          <p className="text-4xl mb-3">📡</p>
          <p className="text-white/40 font-bold">Nie udało się pobrać danych F1</p>
        </div>
      ) : tab === "standings" ? (
        standingsLoading
          ? <div className="flex flex-col gap-2">{[0,1,2,3,4].map(i => <div key={i} className="skeleton h-14 rounded-2xl" />)}</div>
          : <StandingsTable entries={standings} />
      ) : (
        <div className="flex flex-col gap-2">
          {tabRaces().length === 0 ? (
            <div className="text-center py-16">
              <p className="text-4xl mb-3">🏎️</p>
              <p className="text-white/30 font-semibold">Brak wyścigów w tej kategorii</p>
            </div>
          ) : (
            tabRaces().map(r => <RaceCard key={r.id} r={r} next={r.id === nextId} />)
          )}
        </div>
      )}
    </div>
  );
}
