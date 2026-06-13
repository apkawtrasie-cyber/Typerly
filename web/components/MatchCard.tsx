"use client";
import Link from "next/link";
import Image from "next/image";
import { Match, isLive, isFinished, formatMatchTime, competitionLabel } from "@/lib/supabase";

type Props = {
  match: Match;
  myPrediction?: { predicted_home_score: number; predicted_away_score: number; points_earned: number | null } | null;
  index?: number;
};

export default function MatchCard({ match, myPrediction, index = 0 }: Props) {
  const live = isLive(match.status);
  const finished = isFinished(match.status);

  return (
    <Link href={`/matches/${match.id}`} className="block slide-up" style={{ animationDelay: `${index * 40}ms` }}>
      <div className={`relative overflow-hidden rounded-2xl border transition-all duration-200 active:scale-[0.97] ${
        live ? "border-red-500/30 bg-red-500/5" : "border-white/[0.06] bg-[#111]"
      }`}>
        {/* Górna belka */}
        <div className="flex items-center justify-between px-4 pt-3 pb-2">
          <span className="text-white/30 text-[10px] font-bold uppercase tracking-wider">
            {competitionLabel(match.competition, match.sport_type)}
          </span>
          {live ? (
            <span className="flex items-center gap-1.5 text-red-400 text-[10px] font-black uppercase">
              <span className="w-1.5 h-1.5 rounded-full bg-red-400 pulse-live" />
              NA ŻYWO
            </span>
          ) : finished ? (
            <span className="text-white/20 text-[10px] font-semibold">Zakończony</span>
          ) : (
            <span className="text-[#F5C400]/70 text-[10px] font-semibold">{formatMatchTime(match.match_time)}</span>
          )}
        </div>

        {/* Drużyny + wynik */}
        <div className="flex items-center px-4 pb-3 gap-3">
          {/* Gospodarz */}
          <div className="flex-1 flex flex-col items-center gap-2">
            <TeamLogo url={match.home_team_logo_url} name={match.home_team_name} />
            <span className="text-white text-xs font-bold text-center leading-tight line-clamp-2">{match.home_team_name}</span>
          </div>

          {/* Wynik / vs */}
          <div className="flex flex-col items-center min-w-[72px]">
            {(live || finished) && match.home_score != null ? (
              <div className="score-badge rounded-xl px-4 py-2 text-center">
                <span className="text-[#F5C400] font-black text-2xl tabular-nums">
                  {match.home_score} : {match.away_score}
                </span>
              </div>
            ) : (
              <span className="text-white/20 font-black text-xl">vs</span>
            )}
            {!live && !finished && (
              <span className="text-white/20 text-[10px] mt-1">
                {new Date(match.match_time).toLocaleTimeString("pl-PL", { hour: "2-digit", minute: "2-digit" })}
              </span>
            )}
          </div>

          {/* Gość */}
          <div className="flex-1 flex flex-col items-center gap-2">
            <TeamLogo url={match.away_team_logo_url} name={match.away_team_name} />
            <span className="text-white text-xs font-bold text-center leading-tight line-clamp-2">{match.away_team_name}</span>
          </div>
        </div>

        {/* Mój typ — jeśli jest */}
        {myPrediction && (
          <div className={`border-t border-white/[0.06] px-4 py-2 flex items-center justify-between ${
            myPrediction.points_earned != null ? "bg-[#F5C400]/5" : ""
          }`}>
            <span className="text-white/30 text-[10px] font-semibold">Twój typ</span>
            <span className="text-[#F5C400] font-black text-sm">
              {myPrediction.predicted_home_score} : {myPrediction.predicted_away_score}
            </span>
            {myPrediction.points_earned != null && (
              <span className={`text-[10px] font-black px-2 py-0.5 rounded-full ${
                myPrediction.points_earned > 0 ? "bg-green-500/20 text-green-400" : "bg-white/10 text-white/40"
              }`}>
                +{myPrediction.points_earned} pkt
              </span>
            )}
          </div>
        )}
      </div>
    </Link>
  );
}

export function TeamLogo({ url, name }: { url: string | null; name: string }) {
  if (url) {
    return (
      <div className="w-10 h-10 relative">
        <Image src={url} alt={name} fill className="object-contain" unoptimized />
      </div>
    );
  }
  return (
    <div className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center text-lg font-black text-white/40">
      {name[0]}
    </div>
  );
}
