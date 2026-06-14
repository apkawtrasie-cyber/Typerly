"use client";
export const dynamic = "force-dynamic";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Flag, Clock, Trophy } from "lucide-react";

// Dane F1 pobierane wprost z publicznego API ESPN (bez klucza, bez limitu, CORS *).
// Dzięki temu F1 nie obciąża limitu api-sports ani nie wymaga backendu/tabeli.
const ESPN_F1 = "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=2026";

type Driver = { name: string; flag: string | null; order: number };
type Race = {
  id: string;
  name: string;
  date: string;
  state: "pre" | "in" | "post";
  completed: boolean;
  statusLabel: string;
  podium: Driver[];
};

function parseRaces(json: any): Race[] {
  const events: any[] = json?.events ?? [];
  return events.map((e) => {
    const comp = e?.competitions?.[0] ?? {};
    const type = comp?.status?.type ?? {};
    const competitors: any[] = comp?.competitors ?? [];
    const podium: Driver[] = competitors
      .filter((c) => typeof c.order === "number")
      .sort((a, b) => a.order - b.order)
      .slice(0, 3)
      .map((c) => ({
        name: c?.athlete?.displayName ?? "?",
        flag: c?.athlete?.flag?.href ?? null,
        order: c.order,
      }));
    return {
      id: String(e.id),
      name: e.shortName ?? e.name ?? "Grand Prix",
      date: e.date,
      state: (type.state ?? "pre") as Race["state"],
      completed: !!type.completed,
      statusLabel: type.description ?? "",
      podium,
    };
  });
}

function fmtDate(iso: string) {
  return new Date(iso).toLocaleString("pl-PL", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

const MEDAL = ["🥇", "🥈", "🥉"];

function RaceCard({ r, next }: { r: Race; next: boolean }) {
  const finished = r.state === "post";
  const live = r.state === "in";
  return (
    <div className={`rounded-2xl border p-4 ${
      live ? "border-red-500/40 bg-red-500/[0.06]" :
      next ? "border-[#F5C400]/40 bg-[#F5C400]/[0.06]" :
      "border-white/[0.06] bg-[#111]"
    }`}>
      <div className="flex items-start justify-between gap-3 mb-1">
        <div className="flex items-center gap-2 min-w-0">
          <Flag size={14} className={live ? "text-red-400" : next ? "text-[#F5C400]" : "text-white/30"} />
          <p className="text-white font-black text-sm truncate">{r.name}</p>
        </div>
        {live && <span className="flex-shrink-0 flex items-center gap-1 text-red-400 text-[10px] font-black"><span className="w-1.5 h-1.5 rounded-full bg-red-400 animate-pulse" />NA ŻYWO</span>}
        {next && !live && <span className="flex-shrink-0 text-[#F5C400] text-[10px] font-black uppercase tracking-wide">Następny</span>}
      </div>
      <p className="text-white/40 text-xs flex items-center gap-1.5 mb-2"><Clock size={11} /> {fmtDate(r.date)}</p>

      {finished && r.podium.length > 0 ? (
        <div className="flex flex-col gap-1.5 mt-3">
          {r.podium.map((d) => (
            <div key={d.order} className="flex items-center gap-2">
              <span className="text-base leading-none w-5">{MEDAL[d.order - 1]}</span>
              {d.flag && <img src={d.flag} alt="" className="w-5 h-3.5 object-cover rounded-sm" />}
              <span className="text-white/90 text-sm font-semibold">{d.name}</span>
            </div>
          ))}
        </div>
      ) : finished ? (
        <p className="text-white/30 text-xs mt-2">Wyniki niedostępne</p>
      ) : null}
    </div>
  );
}

export default function F1Page() {
  const router = useRouter();
  const [races, setRaces] = useState<Race[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

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

  const now = Date.now();
  const upcoming = races.filter((r) => r.state !== "post");
  const finished = races.filter((r) => r.state === "post").reverse();
  const nextId = upcoming.find((r) => r.state !== "in" && new Date(r.date).getTime() >= now)?.id;

  return (
    <div className="px-4 pt-6 pb-nav fade-in">
      <div className="flex items-center gap-3 mb-5">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.06] flex items-center justify-center">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <div className="flex-1">
          <h1 className="text-white font-black text-2xl font-archivo flex items-center gap-2">🏎️ Formuła 1</h1>
          <p className="text-white/30 text-xs">Sezon 2026 · dane: ESPN</p>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col gap-2">{[0, 1, 2, 3].map((i) => <div key={i} className="skeleton h-20 rounded-2xl" />)}</div>
      ) : error ? (
        <div className="text-center py-16">
          <p className="text-4xl mb-3">📡</p>
          <p className="text-white/40 font-bold">Nie udało się pobrać danych F1</p>
        </div>
      ) : (
        <>
          {upcoming.length > 0 && (
            <div className="mb-6">
              <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3 flex items-center gap-2">
                <Clock size={13} className="text-[#F5C400]" /> Nadchodzące wyścigi ({upcoming.length})
              </h2>
              <div className="flex flex-col gap-2">
                {upcoming.map((r) => <RaceCard key={r.id} r={r} next={r.id === nextId} />)}
              </div>
            </div>
          )}
          {finished.length > 0 && (
            <div className="mb-6">
              <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3 flex items-center gap-2">
                <Trophy size={13} className="text-[#F5C400]" /> Zakończone ({finished.length})
              </h2>
              <div className="flex flex-col gap-2">
                {finished.map((r) => <RaceCard key={r.id} r={r} next={false} />)}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
