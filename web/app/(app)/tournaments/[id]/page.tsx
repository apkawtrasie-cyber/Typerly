"use client";
export const dynamic = 'force-dynamic';
import { useEffect, useState, useCallback, useRef } from "react";
import { useParams, useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { ArrowLeft, Plus, Trash2, Trophy, Gift, Copy, Check, Users, Crown, Shuffle, ListOrdered, Camera, GripVertical, Info, QrCode, UserPlus, Download } from "lucide-react";
import Image from "next/image";
import { useLang } from "@/contexts/LangContext";
import nextDynamic from "next/dynamic";
const QRCodeSVG = nextDynamic(() => import("qrcode.react").then(m => m.QRCodeSVG), { ssr: false });
import {
  DndContext, closestCenter, PointerSensor, TouchSensor,
  useSensor, useSensors, DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext, verticalListSortingStrategy,
  useSortable, arrayMove,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";

type Team = { id: string; name: string; logo_url: string | null; tournament_id: string };
type UserTeam = { id?: string; name: string; logo_url: string | null };
type KnockoutMatch = {
  id: string;
  home_team_name: string;
  away_team_name: string;
  home_team_logo: string | null;
  away_team_logo: string | null;
  home_score: number | null;
  away_score: number | null;
  round_name: string;
  knockout_round: number;
  knockout_slot: number;
  status: string | null;
  match_phase: string;
};
type Tournament = {
  id: string;
  name: string;
  admin_id: string;
  invite_code: string;
  prize_description: string | null;
};

// z-index above BottomNav (z-50) and FAB overlay (z-[60])
const MODAL_Z = "z-[200]";

function TeamAvatar({ url, name, size = 10 }: { url: string | null; name: string; size?: number }) {
  const cls = `w-${size} h-${size} rounded-xl flex-shrink-0`;
  if (url) return (
    <div className={`${cls} relative overflow-hidden`}>
      <Image src={url} alt={name} fill className="object-contain" unoptimized />
    </div>
  );
  return (
    <div className={`${cls} bg-white/10 flex items-center justify-center text-white/50 font-black text-sm`}>
      {name.slice(0, 2).toUpperCase()}
    </div>
  );
}

// Sheet backdrop — covers full screen including bottom nav
function Sheet({ onClose, children }: { onClose: () => void; children: React.ReactNode }) {
  return (
    <div
      onClick={onClose}
      className={`fixed inset-0 ${MODAL_Z} bg-black/80 backdrop-blur-sm flex flex-col justify-end`}
      style={{ paddingBottom: 0 }}
    >
      <div
        onClick={e => e.stopPropagation()}
        className="bg-[#1e1e1e] border-t border-white/[0.08] rounded-t-3xl w-full max-w-lg mx-auto"
        style={{ paddingBottom: "calc(5.5rem + env(safe-area-inset-bottom, 0px))" }}
      >
        {children}
      </div>
    </div>
  );
}

function CenterModal({ onClose, children }: { onClose: () => void; children: React.ReactNode }) {
  return (
    <div
      onClick={onClose}
      className={`fixed inset-0 ${MODAL_Z} bg-black/80 backdrop-blur-sm flex items-center justify-center px-4`}
    >
      <div onClick={e => e.stopPropagation()} className="bg-[#1e1e1e] border border-white/[0.08] rounded-2xl p-5 w-full max-w-xs">
        {children}
      </div>
    </div>
  );
}

// BYE badge z tooltipem — klikalny, wyświetla wyjaśnienie
function ByeBadge({ byeCount, rank }: { byeCount: number; rank: number }) {
  const [open, setOpen] = useState(false);
  if (rank >= byeCount) return null;
  return (
    <div className="relative flex-shrink-0">
      <button
        onClick={e => { e.stopPropagation(); setOpen(v => !v); }}
        className="flex items-center gap-1 text-[9px] font-black text-[#F5C400] bg-[#F5C400]/10 border border-[#F5C400]/30 px-1.5 py-0.5 rounded"
      >
        BYE <Info size={9} />
      </button>
      {open && (
        <div
          className="absolute right-0 bottom-full mb-2 w-56 bg-[#2a2a2a] border border-white/10 rounded-xl p-3 z-10 shadow-xl"
          onClick={e => e.stopPropagation()}
        >
          <p className="text-white font-bold text-xs mb-1">Wolny los 🎖️</p>
          <p className="text-white/50 text-[11px] leading-relaxed">
            Ta drużyna automatycznie przechodzi do następnej rundy bez grania meczu — bo liczba drużyn nie jest potęgą 2.
          </p>
          <p className="text-[#F5C400]/70 text-[11px] mt-1.5 leading-relaxed">
            Zmień kolejność przytrzymując i przeciągając ≡ aby wybrać kto dostaje wolny los.
          </p>
          <button onClick={() => setOpen(false)} className="mt-2 text-white/30 text-[11px] font-bold">Zamknij</button>
        </div>
      )}
    </div>
  );
}

// Pojedynczy wiersz drużyny z drag handle
function SortableTeamRow({
  team, rank, byeCount, isAdmin, onDelete,
}: {
  team: Team; rank: number; byeCount: number; isAdmin: boolean; onDelete: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: team.id });
  const style = { transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? 0.5 : 1 };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${
        rank < byeCount ? "border-[#F5C400]/25 bg-[#F5C400]/5" : "bg-[#1e1e1e] border-white/[0.12]"
      }`}
    >
      {/* Drag handle — long press on mobile */}
      {isAdmin && (
        <button
          {...attributes}
          {...listeners}
          className="text-white/20 touch-none cursor-grab active:cursor-grabbing p-0.5 -ml-1 flex-shrink-0"
          aria-label="Przeciągnij"
        >
          <GripVertical size={16} />
        </button>
      )}
      <span className={`text-xs font-black w-4 flex-shrink-0 ${rank < byeCount ? "text-[#F5C400]" : "text-white/20"}`}>
        {rank + 1}
      </span>
      <TeamAvatar url={team.logo_url} name={team.name} size={8} />
      <span className="text-white font-semibold text-sm flex-1 truncate">{team.name}</span>
      <ByeBadge byeCount={byeCount} rank={rank} />
      {isAdmin && (
        <button onClick={onDelete} className="text-white/20 hover:text-red-400 transition p-1 flex-shrink-0">
          <Trash2 size={14} />
        </button>
      )}
    </div>
  );
}

export default function TournamentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { t } = useLang();

  const [tournament, setTournament] = useState<Tournament | null>(null);
  const [teams, setTeams] = useState<Team[]>([]);
  const [userTeams, setUserTeams] = useState<UserTeam[]>([]);
  const [matches, setMatches] = useState<KnockoutMatch[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Add team dialog
  const [addOpen, setAddOpen] = useState(false);
  const [teamName, setTeamName] = useState("");
  const [logoPreview, setLogoPreview] = useState<string | null>(null);
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [adding, setAdding] = useState(false);
  const [uploadError, setUploadError] = useState("");
  const fileRef = useRef<HTMLInputElement>(null);

  // Result dialog
  const [resultMatch, setResultMatch] = useState<KnockoutMatch | null>(null);
  const [scoreH, setScoreH] = useState("");
  const [scoreA, setScoreA] = useState("");
  const [savingResult, setSavingResult] = useState(false);

  // Seeding dialog
  const [seedingOpen, setSeedingOpen] = useState(false);
  const [seedOrder, setSeedOrder] = useState<Team[]>([]);
  const [generating, setGenerating] = useState(false);

  const [copied, setCopied] = useState(false);
  const [isMember, setIsMember] = useState(false);
  const [joining, setJoining] = useState(false);
  const [qrOpen, setQrOpen] = useState(false);

  // dnd-kit sensors: mouse/pointer + touch (250ms long press)
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 250, tolerance: 8 } }),
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const oldIdx = teams.findIndex(t => t.id === active.id);
    const newIdx = teams.findIndex(t => t.id === over.id);
    setTeams(prev => arrayMove(prev, oldIdx, newIdx));
  }

  const load = useCallback(async () => {
    const { data: { user } } = await supabase.auth.getUser();
    setUserId(user?.id ?? null);

    const [{ data: tr }, { data: tm }, { data: km }, { data: ut }, { data: mem }] = await Promise.all([
      supabase.from("custom_tournaments").select("*").eq("id", id).single(),
      supabase.from("custom_teams").select("*").eq("tournament_id", id).order("created_at"),
      supabase.from("custom_matches").select("*").eq("tournament_id", id)
        .eq("match_phase", "knockout").order("knockout_round", { ascending: false }).order("knockout_slot"),
      user ? supabase.from("user_teams").select("*").order("name") : Promise.resolve({ data: [] }),
      user ? supabase.from("tournament_members").select("id").eq("tournament_id", id).eq("user_id", user.id).maybeSingle()
           : Promise.resolve({ data: null }),
    ]);

    setTournament(tr as Tournament);
    setTeams((tm ?? []) as Team[]);
    setMatches((km ?? []) as KnockoutMatch[]);
    setUserTeams((ut ?? []) as UserTeam[]);
    setIsMember(!!mem);
    setLoading(false);
  }, [id]);

  useEffect(() => { load(); }, [load]);

  const isAdmin = tournament?.admin_id === userId;

  // Filter user library to exclude teams already in this tournament
  const existingNames = new Set(teams.map(t => t.name.toLowerCase()));
  const libraryTeams = userTeams.filter(t => !existingNames.has(t.name.toLowerCase()));

  async function joinTournament() {
    if (!userId || !tournament) return;
    setJoining(true);
    await supabase.from("tournament_members").insert({ tournament_id: tournament.id, user_id: userId });
    setIsMember(true);
    setJoining(false);
  }

  const joinUrl = typeof window !== "undefined"
    ? `${window.location.origin}/join?code=${tournament?.invite_code ?? ""}`
    : "";

  function openAdd() {
    setTeamName(""); setLogoPreview(null); setLogoFile(null); setUploadError("");
    setAddOpen(true);
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadError("");
    // Show preview immediately from original file
    const reader = new FileReader();
    reader.onload = ev => setLogoPreview(ev.target?.result as string);
    reader.readAsDataURL(file);
    setLogoFile(file);
    // Reset input so the same file can be re-selected
    e.target.value = "";
  }

  // Compress + resize to WebP, max 512×512, quality 0.85
  async function compressToWebP(file: File): Promise<Blob> {
    return new Promise((resolve, reject) => {
      const img = new window.Image();
      img.onload = () => {
        const MAX = 512;
        let { width, height } = img;
        if (width > MAX || height > MAX) {
          if (width > height) { height = Math.round((height * MAX) / width); width = MAX; }
          else { width = Math.round((width * MAX) / height); height = MAX; }
        }
        const canvas = document.createElement("canvas");
        canvas.width = width; canvas.height = height;
        const ctx = canvas.getContext("2d");
        if (!ctx) { reject(new Error("canvas")); return; }
        ctx.drawImage(img, 0, 0, width, height);
        canvas.toBlob(blob => {
          if (blob) resolve(blob);
          else reject(new Error("toBlob failed"));
        }, "image/webp", 0.85);
      };
      img.onerror = () => reject(new Error("load"));
      img.src = URL.createObjectURL(file);
    });
  }

  async function uploadLogo(file: File): Promise<string | null> {
    try {
      const compressed = await compressToWebP(file);
      const path = `tournament-logos/${id}/${Date.now()}.webp`;
      const { error } = await supabase.storage
        .from("team-logos")
        .upload(path, compressed, { contentType: "image/webp", upsert: true });
      if (error) { setUploadError("Błąd uploadu: " + error.message); return null; }
      return supabase.storage.from("team-logos").getPublicUrl(path).data.publicUrl;
    } catch (err) {
      setUploadError("Nie udało się przetworzyć zdjęcia");
      return null;
    }
  }

  async function addTeamNew() {
    if (!teamName.trim()) return;
    setAdding(true);
    let logoUrl: string | null = null;
    if (logoFile) logoUrl = await uploadLogo(logoFile);
    const { error } = await supabase.from("custom_teams").insert({
      tournament_id: id, name: teamName.trim(), logo_url: logoUrl,
    });
    if (!error) {
      // Save to user library
      await supabase.from("user_teams").upsert(
        { user_id: userId, name: teamName.trim(), logo_url: logoUrl },
        { onConflict: "user_id,name", ignoreDuplicates: true }
      );
      setAddOpen(false);
      await load();
    }
    setAdding(false);
  }

  async function addFromLibrary(ut: UserTeam) {
    setAdding(true);
    await supabase.from("custom_teams").insert({
      tournament_id: id, name: ut.name, logo_url: ut.logo_url,
    });
    setAdding(false);
    await load();
    // keep dialog open so user can add more
  }

  async function deleteTeam(teamId: string) {
    await supabase.from("custom_teams").delete().eq("id", teamId);
    await load();
  }

  function openSeeding() { setSeedOrder([...teams]); setSeedingOpen(true); }

  async function generateRandom() {
    setGenerating(true);
    const shuffled = [...teams].sort(() => Math.random() - 0.5);
    await generateKnockout(shuffled);
    setGenerating(false); setSeedingOpen(false);
  }

  async function generateManual() {
    setGenerating(true);
    await generateKnockout(seedOrder);
    setGenerating(false); setSeedingOpen(false);
  }

  async function generateKnockout(ordered: Team[]) {
    await supabase.from("custom_matches").delete().eq("tournament_id", id).eq("match_phase", "knockout");
    const n = ordered.length;
    if (n < 2) return;
    let slots = 1;
    while (slots < n) slots *= 2;
    const seeded: (Team | null)[] = Array(slots).fill(null);
    for (let i = 0; i < n; i++) seeded[i] = ordered[i];
    const roundNames: Record<number, string> = { 1: "Finał", 2: "Półfinał", 4: "Ćwierćfinał", 8: "1/8 finału" };
    const firstRoundMatches = slots / 2;
    const byeTeams: Record<number, Team> = {};

    for (let i = 0; i < firstRoundMatches; i++) {
      const home = seeded[i]; const away = seeded[slots - 1 - i];
      if (!home && !away) continue;
      if (!home || !away) { byeTeams[i] = (home ?? away)!; continue; }
      const mt = new Date(Date.now() + 86400000 + i * 7200000).toISOString();
      await supabase.from("custom_matches").insert({
        tournament_id: id, home_team_id: home.id, away_team_id: away.id,
        home_team_name: home.name, away_team_name: away.name,
        home_team_logo: home.logo_url, away_team_logo: away.logo_url,
        match_time: mt, round_name: roundNames[firstRoundMatches] ?? "Faza pucharowa",
        match_phase: "knockout", knockout_round: firstRoundMatches, knockout_slot: i,
      });
    }

    let currentRound = firstRoundMatches / 2, dayOffset = 7;
    let prevByes = { ...byeTeams };
    while (currentRound >= 1) {
      const rn = roundNames[currentRound] ?? "Faza pucharowa";
      for (let i = 0; i < currentRound; i++) {
        const preHome = prevByes[i * 2], preAway = prevByes[i * 2 + 1];
        await supabase.from("custom_matches").insert({
          tournament_id: id,
          home_team_id: preHome?.id ?? null, away_team_id: preAway?.id ?? null,
          home_team_name: preHome?.name ?? "TBD", away_team_name: preAway?.name ?? "TBD",
          home_team_logo: preHome?.logo_url ?? null, away_team_logo: preAway?.logo_url ?? null,
          match_time: new Date(Date.now() + dayOffset * 86400000 + i * 7200000).toISOString(),
          round_name: rn, match_phase: "knockout", knockout_round: currentRound, knockout_slot: i,
        });
      }
      currentRound = Math.floor(currentRound / 2); dayOffset += 7; prevByes = {};
    }
    await load();
  }

  async function saveResult() {
    if (!resultMatch) return;
    setSavingResult(true);
    const h = parseInt(scoreH), a = parseInt(scoreA);
    if (isNaN(h) || isNaN(a)) { setSavingResult(false); return; }
    await supabase.from("custom_matches").update({ home_score: h, away_score: a, status: "FT" }).eq("id", resultMatch.id);
    const slot = resultMatch.knockout_slot, round = resultMatch.knockout_round;
    if (round > 1) {
      const nextRound = Math.floor(round / 2), nextSlot = Math.floor(slot / 2), isHome = slot % 2 === 0;
      const winnerIsHome = h >= a;
      const winnerName = winnerIsHome ? resultMatch.home_team_name : resultMatch.away_team_name;
      const winnerLogo = winnerIsHome ? resultMatch.home_team_logo : resultMatch.away_team_logo;
      const { data: nxt } = await supabase.from("custom_matches").select("id")
        .eq("tournament_id", id).eq("match_phase", "knockout").eq("knockout_round", nextRound).eq("knockout_slot", nextSlot).maybeSingle();
      if (nxt) await supabase.from("custom_matches").update(
        isHome ? { home_team_name: winnerName, home_team_logo: winnerLogo }
               : { away_team_name: winnerName, away_team_logo: winnerLogo }
      ).eq("id", (nxt as { id: string }).id);
    }
    setResultMatch(null); setScoreH(""); setScoreA(""); setSavingResult(false);
    await load();
  }

  function copyCode() {
    navigator.clipboard.writeText(tournament?.invite_code ?? "");
    setCopied(true); setTimeout(() => setCopied(false), 2000);
  }

  const rounds = matches.reduce<Record<number, KnockoutMatch[]>>((acc, m) => {
    if (!acc[m.knockout_round]) acc[m.knockout_round] = [];
    acc[m.knockout_round].push(m); return acc;
  }, {});
  const sortedRounds = Object.keys(rounds).map(Number).sort((a, b) => b - a);

  const byeCount = (() => {
    if (teams.length < 2) return 0;
    let slots = 1; while (slots < teams.length) slots *= 2; return slots - teams.length;
  })();

  if (loading) return (
    <div className="flex justify-center pt-20">
      <div className="w-8 h-8 border-2 border-[#F5C400] border-t-transparent rounded-full animate-spin" />
    </div>
  );
  if (!tournament) return <div className="flex justify-center pt-20 text-white/40">Turniej nie istnieje</div>;

  return (
    <div className="flex flex-col min-h-screen pb-24 fade-in">
      {/* Header */}
      <div className="px-4 pt-6 pb-4">
        <button onClick={() => router.back()} className="text-white/40 mb-4 flex items-center gap-1 text-sm">
          <ArrowLeft size={18} /> Wstecz
        </button>
        <div className="rounded-2xl bg-gradient-to-br from-purple-900/40 to-purple-900/10 border border-purple-500/20 p-4">
          <div className="flex items-start gap-3">
            <div className="w-12 h-12 rounded-xl bg-purple-500/20 border border-purple-500/30 flex items-center justify-center flex-shrink-0">
              <Trophy size={22} className="text-purple-300" />
            </div>
            <div className="flex-1 min-w-0">
              <h1 className="text-white font-black text-xl font-archivo truncate">{tournament.name}</h1>
              {tournament.prize_description && (
                <p className="flex items-center gap-1 text-white/50 text-sm mt-0.5"><Gift size={13} /> {tournament.prize_description}</p>
              )}
              <button onClick={copyCode} className="flex items-center gap-1.5 mt-2 text-white/40 text-xs hover:text-[#F5C400] transition">
                {copied ? <Check size={12} className="text-green-400" /> : <Copy size={12} />}
                <span className="font-mono tracking-wider">{tournament.invite_code}</span>
              </button>
            </div>
            <div className="flex flex-col gap-2 items-end flex-shrink-0">
              {isAdmin && <Crown size={16} className="text-[#F5C400]" />}
              {isAdmin && (
                <button onClick={() => setQrOpen(true)}
                  className="flex items-center gap-1 text-purple-300 text-[11px] font-bold bg-purple-500/10 border border-purple-500/20 px-2 py-1 rounded-lg">
                  <QrCode size={12} /> QR
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Dołącz — dla nie-członków */}
        {!isMember && !isAdmin && (
          <button
            onClick={joinTournament}
            disabled={joining}
            className="mt-3 w-full bg-purple-600 text-white font-black py-4 rounded-2xl active:scale-95 transition flex items-center justify-center gap-2 text-lg disabled:opacity-50"
          >
            <UserPlus size={20} />
            {joining ? "Dołączanie..." : "Dołącz do turnieju"}
          </button>
        )}
      </div>

      {/* Teams */}
      <div className="px-4 mb-6">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest flex items-center gap-2">
            <Users size={12} /> Drużyny ({teams.length})
          </h2>
          {isAdmin && (
            <button onClick={openAdd} className="flex items-center gap-1 text-[#F5C400] text-xs font-bold">
              <Plus size={14} /> Dodaj
            </button>
          )}
        </div>

        {teams.length === 0 ? (
          <div className="rounded-2xl bg-white/[0.03] border border-white/[0.12] px-4 py-8 text-center">
            <p className="text-white/40 text-sm">Brak drużyn</p>
            {isAdmin && (
              <button onClick={openAdd} className="mt-3 text-[#F5C400] text-sm font-bold">+ Dodaj pierwszą drużynę</button>
            )}
          </div>
        ) : (
          <>
            {isAdmin && (
              <p className="text-white/25 text-[11px] mb-2 flex items-center gap-1">
                <GripVertical size={11} /> Przytrzymaj i przeciągnij aby ustawić kolejność w drabince
              </p>
            )}
            <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
              <SortableContext items={teams.map(t => t.id)} strategy={verticalListSortingStrategy}>
                <div className="flex flex-col gap-2">
                  {teams.map((team, i) => (
                    <SortableTeamRow
                      key={team.id}
                      team={team}
                      rank={i}
                      byeCount={byeCount}
                      isAdmin={isAdmin}
                      onDelete={() => deleteTeam(team.id)}
                    />
                  ))}
                </div>
              </SortableContext>
            </DndContext>
          </>
        )}

        {isAdmin && teams.length >= 2 && matches.length === 0 && (
          <button onClick={() => generateKnockout(teams)}
            disabled={generating}
            className="mt-4 w-full bg-purple-600 text-white font-black py-4 rounded-2xl active:scale-95 transition flex items-center justify-center gap-2 disabled:opacity-50">
            {generating ? <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> Generowanie...</> : <><Trophy size={18} /> Generuj drabinkę</>}
          </button>
        )}
        {isAdmin && teams.length >= 2 && matches.length > 0 && (
          <button onClick={() => generateKnockout(teams)}
            disabled={generating}
            className="mt-3 w-full bg-white/[0.05] border border-white/10 text-white/50 font-bold py-3 rounded-xl active:scale-95 transition text-sm disabled:opacity-40">
            {generating ? "Generowanie..." : "Regeneruj drabinkę (aktualna kolejność)"}
          </button>
        )}
      </div>

      {/* Bracket */}
      {matches.length > 0 && (
        <div className="px-4">
          <h2 className="text-white/40 text-[10px] font-black uppercase tracking-widest mb-3 flex items-center gap-2">
            <Trophy size={12} /> Drabinka
          </h2>
          <div className="flex flex-col gap-5">
            {sortedRounds.map(roundNum => (
              <div key={roundNum}>
                <p className="text-[#F5C400] text-xs font-black uppercase tracking-widest mb-2">
                  {rounds[roundNum][0]?.round_name ?? `Runda ${roundNum}`}
                </p>
                <div className="flex flex-col gap-2">
                  {rounds[roundNum].map(m => (
                    <div key={m.id} className={`rounded-2xl border overflow-hidden ${m.status === "FT" ? "border-white/10 bg-[#1e1e1e]" : "border-white/[0.12] bg-[#0d0d0d]"}`}>
                      <div className={`flex items-center gap-3 px-4 py-2.5 ${m.status === "FT" && (m.home_score ?? 0) > (m.away_score ?? 0) ? "bg-[#F5C400]/5" : ""}`}>
                        <TeamAvatar url={m.home_team_logo} name={m.home_team_name} size={7} />
                        <span className={`flex-1 text-sm font-semibold truncate ${m.home_team_name === "TBD" ? "text-white/30" : "text-white"}`}>{m.home_team_name}</span>
                        {m.status === "FT" && <span className={`font-black text-lg tabular-nums ${(m.home_score ?? 0) > (m.away_score ?? 0) ? "text-[#F5C400]" : "text-white/40"}`}>{m.home_score}</span>}
                      </div>
                      <div className="h-px bg-white/[0.06] mx-4" />
                      <div className={`flex items-center gap-3 px-4 py-2.5 ${m.status === "FT" && (m.away_score ?? 0) > (m.home_score ?? 0) ? "bg-[#F5C400]/5" : ""}`}>
                        <TeamAvatar url={m.away_team_logo} name={m.away_team_name} size={7} />
                        <span className={`flex-1 text-sm font-semibold truncate ${m.away_team_name === "TBD" ? "text-white/30" : "text-white"}`}>{m.away_team_name}</span>
                        {m.status === "FT" && <span className={`font-black text-lg tabular-nums ${(m.away_score ?? 0) > (m.home_score ?? 0) ? "text-[#F5C400]" : "text-white/40"}`}>{m.away_score}</span>}
                      </div>
                      {isAdmin && m.home_team_name !== "TBD" && m.away_team_name !== "TBD" && m.status !== "FT" && (
                        <button onClick={() => { setResultMatch(m); setScoreH(""); setScoreA(""); }}
                          className="w-full border-t border-white/[0.12] text-white/40 text-xs font-semibold py-2 hover:text-[#F5C400] transition">
                          Wpisz wynik
                        </button>
                      )}
                      {m.status === "FT" && isAdmin && (
                        <button onClick={() => { setResultMatch(m); setScoreH(String(m.home_score ?? "")); setScoreA(String(m.away_score ?? "")); }}
                          className="w-full border-t border-white/[0.12] text-white/25 text-[11px] py-1.5">
                          Zmień wynik
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── ADD TEAM SHEET ── */}
      {addOpen && (
        <Sheet onClose={() => setAddOpen(false)}>
          <div className="px-5 pt-5 pb-3">
            <h3 className="text-white font-black text-lg mb-4">Dodaj drużynę</h3>

            {/* Library chips */}
            {libraryTeams.length > 0 && (
              <>
                <p className="text-white/30 text-[10px] font-black uppercase tracking-widest mb-2">Twoje drużyny</p>
                <div className="flex flex-wrap gap-2 mb-4">
                  {libraryTeams.map(ut => (
                    <button
                      key={ut.name}
                      disabled={adding}
                      onClick={() => addFromLibrary(ut)}
                      className="flex items-center gap-1.5 bg-white/[0.06] border border-white/10 rounded-full px-3 py-1.5 active:scale-95 transition disabled:opacity-40"
                    >
                      {ut.logo_url ? (
                        <Image src={ut.logo_url} alt={ut.name} width={18} height={18} className="rounded-full object-cover" unoptimized />
                      ) : (
                        <div className="w-4 h-4 rounded-full bg-[#F5C400]/30 flex items-center justify-center text-[8px] font-black text-[#F5C400]">
                          {ut.name[0]?.toUpperCase()}
                        </div>
                      )}
                      <span className="text-white text-xs font-semibold">{ut.name}</span>
                    </button>
                  ))}
                </div>
                <div className="flex items-center gap-3 mb-4">
                  <div className="flex-1 h-px bg-white/[0.07]" />
                  <span className="text-white/30 text-xs">lub nowa</span>
                  <div className="flex-1 h-px bg-white/[0.07]" />
                </div>
              </>
            )}

            {/* Logo picker */}
            <div className="flex gap-4 items-start mb-4">
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="relative w-20 h-20 rounded-2xl border-2 border-dashed border-[#F5C400]/40 bg-[#F5C400]/5 flex flex-col items-center justify-center flex-shrink-0 active:scale-95 transition overflow-hidden"
              >
                {logoPreview ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={logoPreview} alt="logo" className="absolute inset-0 w-full h-full object-cover" />
                ) : (
                  <>
                    <Camera size={22} className="text-[#F5C400]/60" />
                    <span className="text-[#F5C400]/50 text-[10px] mt-1 font-semibold">Logo</span>
                  </>
                )}
              </button>
              <div className="flex-1">
                <input
                  value={teamName}
                  onChange={e => setTeamName(e.target.value)}
                  placeholder="Nazwa drużyny"
                  autoFocus
                  className="w-full bg-[#1e1e1e] border border-white/10 rounded-xl px-4 py-3 text-white text-sm focus:border-[#F5C400]/40 focus:outline-none"
                  onKeyDown={e => { if (e.key === "Enter" && teamName.trim()) addTeamNew(); }}
                />
                <p className="text-white/20 text-[11px] mt-1.5 pl-1">
                  Kliknij kwadrat aby wybrać zdjęcie • WebP auto
                </p>
                {uploadError && <p className="text-red-400 text-[11px] mt-1 pl-1">{uploadError}</p>}
              </div>
            </div>

            {/* Hidden file input */}
            <input ref={fileRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleFileChange} />

            <div className="flex gap-3 pb-1">
              <button onClick={() => setAddOpen(false)}
                className="flex-1 bg-white/5 border border-white/10 text-white/60 font-bold py-3.5 rounded-xl">
                Anuluj
              </button>
              <button onClick={addTeamNew} disabled={adding || !teamName.trim()}
                className="flex-1 bg-[#F5C400] text-black font-black py-3.5 rounded-xl disabled:opacity-40 active:scale-95 transition">
                {adding ? "Dodawanie..." : "Dodaj"}
              </button>
            </div>
          </div>
        </Sheet>
      )}

      {/* ── SEEDING SHEET ── */}
      {seedingOpen && (
        <Sheet onClose={() => setSeedingOpen(false)}>
          <div className="px-5 pt-5 flex flex-col" style={{ maxHeight: "calc(85vh - 5.5rem - env(safe-area-inset-bottom, 0px))" }}>
            <h3 className="text-white font-black text-lg mb-1 flex-shrink-0">Generuj drabinkę</h3>
            {byeCount > 0 && (
              <p className="text-white/40 text-xs mb-3 flex-shrink-0">
                Pierwsze <span className="text-[#F5C400] font-bold">{byeCount}</span> miejsc dostaje wolny los (awans bez meczu)
              </p>
            )}
            {!byeCount && <div className="mb-3 flex-shrink-0" />}

            <div className="flex-1 overflow-y-auto flex flex-col gap-2 mb-4 min-h-0">
              {seedOrder.map((team, i) => (
                <div key={team.id} className={`flex items-center gap-3 rounded-xl px-3 py-2.5 border ${i < byeCount ? "border-[#F5C400]/30 bg-[#F5C400]/5" : "border-white/[0.12] bg-white/[0.03]"}`}>
                  <span className={`text-xs font-black w-5 ${i < byeCount ? "text-[#F5C400]" : "text-white/30"}`}>{i + 1}</span>
                  <TeamAvatar url={team.logo_url} name={team.name} size={7} />
                  <span className="flex-1 text-white text-sm font-semibold truncate">{team.name}</span>
                  {i < byeCount && <span className="text-[9px] font-black text-[#F5C400] bg-[#F5C400]/10 px-1.5 py-0.5 rounded">BYE</span>}
                  <div className="flex flex-col gap-0.5">
                    <button disabled={i === 0}
                      onClick={() => setSeedOrder(prev => { const a = [...prev]; [a[i-1], a[i]] = [a[i], a[i-1]]; return a; })}
                      className="text-white/30 hover:text-white disabled:opacity-20 text-xs leading-none px-1">▲</button>
                    <button disabled={i === seedOrder.length - 1}
                      onClick={() => setSeedOrder(prev => { const a = [...prev]; [a[i], a[i+1]] = [a[i+1], a[i]]; return a; })}
                      className="text-white/30 hover:text-white disabled:opacity-20 text-xs leading-none px-1">▼</button>
                  </div>
                </div>
              ))}
            </div>

            <div className="flex gap-2 pb-1 flex-shrink-0">
              <button onClick={() => setSeedingOpen(false)}
                className="flex-1 bg-white/5 border border-white/10 text-white/60 font-bold py-3.5 rounded-xl text-sm">
                Anuluj
              </button>
              <button onClick={generateRandom} disabled={generating}
                className="flex-1 bg-purple-600/80 text-white font-bold py-3.5 rounded-xl disabled:opacity-40 text-sm flex items-center justify-center gap-1.5">
                <Shuffle size={14} /> Losuj
              </button>
              <button onClick={generateManual} disabled={generating}
                className="flex-1 bg-[#F5C400] text-black font-black py-3.5 rounded-xl disabled:opacity-40 text-sm flex items-center justify-center gap-1.5">
                <ListOrdered size={14} /> Generuj
              </button>
            </div>
          </div>
        </Sheet>
      )}

      {/* ── RESULT MODAL ── */}
      {resultMatch && (
        <Sheet onClose={() => setResultMatch(null)}>
          <div className="px-5 pt-5 pb-2">
            <p className="text-white/30 text-[10px] font-black uppercase tracking-widest mb-4">Wpisz wynik</p>

            {/* Drużyna gospodarz */}
            <div className="flex items-center gap-3 mb-3">
              <TeamAvatar url={resultMatch.home_team_logo} name={resultMatch.home_team_name} size={10} />
              <span className="text-white font-bold text-base flex-1 truncate">{resultMatch.home_team_name}</span>
              <input
                value={scoreH}
                onChange={e => setScoreH(e.target.value)}
                type="number" min="0" inputMode="numeric" placeholder="0"
                autoFocus
                className="w-20 h-16 bg-[#1e1e1e] border-2 border-white/10 rounded-2xl text-white text-center text-4xl font-black focus:border-[#F5C400] focus:outline-none tabular-nums"
              />
            </div>

            {/* Separator */}
            <div className="flex items-center gap-3 mb-3">
              <div className="w-10 h-10 flex-shrink-0" />
              <div className="flex-1 h-px bg-white/[0.06]" />
              <div className="w-20 flex items-center justify-center">
                <span className="text-white/20 font-black text-2xl">:</span>
              </div>
            </div>

            {/* Drużyna gość */}
            <div className="flex items-center gap-3 mb-6">
              <TeamAvatar url={resultMatch.away_team_logo} name={resultMatch.away_team_name} size={10} />
              <span className="text-white font-bold text-base flex-1 truncate">{resultMatch.away_team_name}</span>
              <input
                value={scoreA}
                onChange={e => setScoreA(e.target.value)}
                type="number" min="0" inputMode="numeric" placeholder="0"
                className="w-20 h-16 bg-[#1e1e1e] border-2 border-white/10 rounded-2xl text-white text-center text-4xl font-black focus:border-[#F5C400] focus:outline-none tabular-nums"
              />
            </div>

            <div className="flex gap-3">
              <button onClick={() => setResultMatch(null)}
                className="flex-1 bg-white/5 border border-white/10 text-white/60 font-bold py-4 rounded-2xl text-base">
                Anuluj
              </button>
              <button onClick={saveResult} disabled={savingResult || scoreH === "" || scoreA === ""}
                className="flex-1 bg-[#F5C400] text-black font-black py-4 rounded-2xl text-base disabled:opacity-40 active:scale-95 transition">
                {savingResult ? "Zapisuję..." : "Zapisz wynik"}
              </button>
            </div>
          </div>
        </Sheet>
      )}

      {/* ── QR CODE MODAL ── */}
      {qrOpen && (
        <CenterModal onClose={() => setQrOpen(false)}>
          <h3 className="text-white font-black text-base mb-1 text-center">Zaproś do turnieju</h3>
          <p className="text-white/40 text-xs text-center mb-4">Zeskanuj kod lub udostępnij link</p>

          {/* QR code */}
          <div className="flex justify-center mb-4">
            <div className="bg-white p-4 rounded-2xl">
              <QRCodeSVG
                value={joinUrl}
                size={200}
                level="M"
                includeMargin={false}
              />
            </div>
          </div>

          {/* Invite code */}
          <div className="bg-[#1e1e1e] border border-white/10 rounded-xl px-4 py-3 text-center mb-3">
            <p className="text-white/30 text-[10px] font-bold uppercase tracking-widest mb-1">Kod zaproszenia</p>
            <p className="text-white font-black text-2xl tracking-[0.3em] font-mono">{tournament.invite_code}</p>
          </div>

          {/* Copy link */}
          <button
            onClick={() => { navigator.clipboard.writeText(joinUrl); setCopied(true); setTimeout(() => setCopied(false), 2000); }}
            className="w-full flex items-center justify-center gap-2 bg-white/[0.06] border border-white/10 text-white/70 font-bold py-3 rounded-xl mb-3 text-sm"
          >
            {copied ? <Check size={15} className="text-green-400" /> : <Copy size={15} />}
            {copied ? "Skopiowano!" : "Kopiuj link zaproszenia"}
          </button>

          <button onClick={() => setQrOpen(false)}
            className="w-full bg-[#F5C400] text-black font-black py-3.5 rounded-xl">
            Zamknij
          </button>
        </CenterModal>
      )}
    </div>
  );
}
