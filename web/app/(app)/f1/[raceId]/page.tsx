"use client";
import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { ArrowLeft, CheckCircle2, Trophy } from "lucide-react";
import { supabase } from "@/lib/supabase";

const ESPN_F1 = "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=2026";
const ESPN_STANDINGS = "https://site.api.espn.com/apis/v2/sports/racing/f1/standings";
const MEDAL = ["🥇", "🥈", "🥉"];

type Driver = { name: string; flag: string | null; order: number; team?: string };
type Race = { id: string; name: string; fullName: string; date: string; state: "pre" | "in" | "post"; allDrivers: Driver[] };

function parseRaces(json: any): Race[] {
  return (json?.events ?? []).map((e: any) => {
    const comp = e?.competitions?.[0] ?? {};
    const type = comp?.status?.type ?? {};
    const competitors: any[] = comp?.competitors ?? [];
    return {
      id: String(e.id),
      name: e.shortName ?? e.name ?? "Grand Prix",
      fullName: e.name ?? e.shortName ?? "Grand Prix",
      date: e.date,
      state: (type.state ?? "pre") as "pre" | "in" | "post",
      allDrivers: competitors
        .filter((c: any) => typeof c.order === "number")
        .sort((a: any, b: any) => a.order - b.order)
        .map((c: any) => ({
          name: c?.athlete?.displayName ?? "?",
          flag: c?.athlete?.flag?.href ?? null,
          order: c.order,
          team: c?.team?.shortDisplayName ?? c?.team?.displayName ?? undefined,
        })),
    };
  });
}

// Pobiera listę wszystkich kierowców z tabeli kierowców (zawsze dostępna)
function parseDriversFromStandings(json: any): Driver[] {
  const entries: any[] = json?.standings?.[0]?.entries ?? json?.children?.[0]?.standings?.entries ?? [];
  return entries.map((e: any, i: number) => ({
    name: e?.athlete?.displayName ?? "?",
    flag: e?.athlete?.flag?.href ?? null,
    order: i + 1,
    team: e?.team?.shortDisplayName ?? e?.team?.displayName ?? undefined,
  })).filter(d => d.name !== "?");
}

function fmtDate(iso: string) {
  return new Date(iso).toLocaleString("pl-PL", {
    weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit",
  });
}

export default function F1RacePage() {
  const router = useRouter();
  const { raceId } = useParams<{ raceId: string }>();

  const [race, setRace] = useState<Race | null>(null);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [myPrediction, setMyPrediction] = useState<string | null>(null);
  const [predId, setPredId] = useState<string | null>(null);
  const [selected, setSelected] = useState<Driver | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    Promise.all([
      fetch(ESPN_F1).then(r => r.json()),
      fetch(ESPN_STANDINGS).then(r => r.json()),
    ]).then(([scoreboard, standings]) => {
      if (!active) return;
      const races = parseRaces(scoreboard);
      const found = races.find(r => r.id === raceId) ?? null;
      setRace(found);

      // Jeśli wyścig ma wyniki — użyj kolejności z wyścigu
      // Jeśli nie ma (przyszły/kwalifikacje) — użyj listy ze standings (alfabetycznie/punkty)
      if ((found?.allDrivers?.length ?? 0) > 0) {
        setDrivers(found!.allDrivers);
      } else {
        setDrivers(parseDriversFromStandings(standings));
      }
    }).catch(() => {}).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [raceId]);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      const uid = data.user?.id ?? null;
      setUserId(uid);
      if (!uid) return;
      supabase.from("f1_predictions")
        .select("id, predicted_driver")
        .eq("user_id", uid)
        .eq("race_id", raceId)
        .maybeSingle()
        .then(({ data: pred }) => {
          if (pred) { setMyPrediction(pred.predicted_driver); setPredId(pred.id); }
        });
    });
  }, [raceId]);

  async function savePrediction() {
    if (!selected || !userId || !race) return;
    setSaving(true);
    const payload = {
      user_id: userId, race_id: raceId, race_name: race.fullName, race_date: race.date,
      predicted_driver: selected.name, predicted_driver_flag: selected.flag,
    };
    if (predId) {
      await supabase.from("f1_predictions").update(payload).eq("id", predId);
    } else {
      const { data } = await supabase.from("f1_predictions").insert(payload).select("id").single();
      if (data) setPredId(data.id);
    }
    setMyPrediction(selected.name);
    setSaving(false);
    setSaved(true);
    setSelected(null);
    setTimeout(() => setSaved(false), 2500);
  }

  if (loading) {
    return (
      <div className="px-4 pt-6 pb-nav fade-in">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center mb-6">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <div className="flex flex-col gap-3">{[0,1,2,3,4].map(i => <div key={i} className="skeleton h-14 rounded-2xl" />)}</div>
      </div>
    );
  }

  if (!race) {
    return (
      <div className="px-4 pt-6 pb-nav fade-in text-center">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center mb-8 mx-auto">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <p className="text-4xl mb-3">🏎️</p>
        <p className="text-white/40">Nie znaleziono wyścigu</p>
      </div>
    );
  }

  const finished = race.state === "post";
  const live = race.state === "in";
  const canPredict = !finished && !!userId;

  return (
    <div className="px-4 pt-6 pb-nav fade-in">
      {/* Nagłówek */}
      <div className="flex items-center gap-3 mb-4">
        <button onClick={() => router.back()} className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <div className="flex-1 min-w-0">
          <p className="text-white/40 text-xs">🏎️ Formuła 1</p>
          <h1 className="text-white font-black text-xl font-archivo leading-tight truncate">{race.name}</h1>
        </div>
      </div>

      {/* Baner wyścigu */}
      <div className={`rounded-2xl border p-4 mb-5 ${
        live ? "border-red-500/40 bg-red-500/[0.06] card-glow-live"
        : finished ? "border-white/[0.12] bg-[#1e1e1e] card-glow"
        : "border-[#F5C400]/30 bg-[#F5C400]/[0.05] card-glow-gold"
      }`}>
        <p className="text-white font-black">{race.fullName}</p>
        <p className="text-white/50 text-sm mt-1">{fmtDate(race.date)}</p>
        {live && <p className="text-red-400 text-xs font-black mt-2 flex items-center gap-1.5"><span className="w-1.5 h-1.5 rounded-full bg-red-400 animate-pulse" />TRWA NA ŻYWO</p>}
        {finished && <p className="text-white/30 text-xs mt-2">Wyścig zakończony</p>}
        {!finished && !live && <p className="text-[#F5C400]/80 text-xs font-semibold mt-2">Typuj zwycięzcę poniżej ↓</p>}
      </div>

      {/* Mój obecny typ */}
      {myPrediction && (
        <div className="bg-[#F5C400]/[0.08] border border-[#F5C400]/25 rounded-2xl px-4 py-3 mb-5 flex items-center gap-3 card-glow-gold">
          <Trophy size={18} className="text-[#F5C400] flex-shrink-0" />
          <div className="flex-1 min-w-0">
            <p className="text-white/40 text-[10px] font-black uppercase tracking-widest">Twój typ</p>
            <p className="text-white font-black">{myPrediction}</p>
          </div>
          {saved && <span className="text-green-400 text-xs font-black">✓ Zaktualizowano!</span>}
          {!finished && !saved && <p className="text-white/30 text-xs">Zmień poniżej</p>}
        </div>
      )}

      {/* Wyniki zakończonego wyścigu */}
      {finished && drivers.length > 0 && (
        <div className="mb-5">
          <p className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">Wyniki wyścigu</p>
          <div className="bg-[#1e1e1e] border border-white/[0.12] rounded-2xl overflow-hidden card-glow">
            {drivers.map((d, i) => (
              <div key={d.order} className={`flex items-center px-4 py-3 gap-3 ${i < drivers.length - 1 ? "border-b border-white/[0.05]" : ""} ${
                d.name === myPrediction ? "bg-[#F5C400]/[0.06]" : ""
              }`}>
                <span className={`w-6 text-center font-black text-sm flex-shrink-0 ${
                  i === 0 ? "text-[#F5C400]" : i === 1 ? "text-white/50" : i === 2 ? "text-orange-400/70" : "text-white/25"
                }`}>{i < 3 ? MEDAL[i] : d.order}</span>
                {d.flag ? <img src={d.flag} alt="" className="w-5 h-3.5 object-cover rounded-sm flex-shrink-0" /> : <span className="w-5 flex-shrink-0" />}
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm font-semibold truncate">{d.name}</p>
                  {d.team && <p className="text-white/30 text-[10px]">{d.team}</p>}
                </div>
                {d.name === myPrediction && (
                  <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-[#F5C400]/20 text-[#F5C400]">Twój typ</span>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Typowanie */}
      {canPredict && drivers.length > 0 && (
        <div>
          <p className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3">
            {live ? "Wybierz lidera" : "Kto wygra wyścig?"}
          </p>
          <div className="flex flex-col gap-2 mb-4">
            {drivers.map((d, i) => {
              const isSelected = selected?.name === d.name;
              const isMy = myPrediction === d.name && !selected;
              return (
                <button key={i} onClick={() => setSelected(isSelected ? null : d)}
                  className={`flex items-center gap-3 px-4 py-3 rounded-2xl border transition-all active:scale-[0.98] text-left ${
                    isSelected ? "border-[#F5C400] bg-[#F5C400]/[0.10] card-glow-gold"
                    : isMy ? "border-[#F5C400]/40 bg-[#F5C400]/[0.04]"
                    : "border-white/[0.10] bg-[#1e1e1e] card-glow"
                  }`}>
                  {d.flag
                    ? <img src={d.flag} alt="" className="w-6 h-4 object-cover rounded-sm flex-shrink-0" />
                    : <span className="w-6 h-4 bg-white/10 rounded-sm flex-shrink-0" />
                  }
                  <div className="flex-1 min-w-0">
                    <p className={`font-bold text-sm truncate ${isSelected ? "text-[#F5C400]" : "text-white"}`}>{d.name}</p>
                    {d.team && <p className="text-white/30 text-[10px]">{d.team}</p>}
                  </div>
                  {isSelected && <CheckCircle2 size={18} className="text-[#F5C400] flex-shrink-0" />}
                  {isMy && !isSelected && <span className="text-[10px] text-[#F5C400]/70 font-semibold flex-shrink-0">aktualny</span>}
                </button>
              );
            })}
          </div>

          {selected && (
            <div className="sticky bottom-24 pb-2">
              <button onClick={savePrediction} disabled={saving}
                className="w-full py-4 rounded-2xl bg-[#F5C400] text-black font-black text-base active:scale-[0.97] transition disabled:opacity-50 shadow-[0_4px_24px_rgba(245,196,0,0.35)]">
                {saving ? "Zapisuję..." : saved ? "✓ Zapisano!" : `Typuję: ${selected.name}`}
              </button>
            </div>
          )}

          {!selected && !myPrediction && (
            <p className="text-white/25 text-sm text-center py-4">Wybierz kierowcę żeby postawić typ</p>
          )}
        </div>
      )}

      {!userId && (
        <div className="text-center py-8">
          <p className="text-white/30 text-sm">Zaloguj się żeby typować wyniki</p>
        </div>
      )}
    </div>
  );
}
