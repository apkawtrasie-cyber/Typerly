import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storageKey: "typerly-auth",
    },
  },
);

export type Match = {
  id: string;
  home_team_name: string;
  away_team_name: string;
  home_team_logo_url: string | null;
  away_team_logo_url: string | null;
  match_time: string;
  status: string;
  home_score: number | null;
  away_score: number | null;
  competition: string | null;
  sport_type: string;
  league_id: string | null;
};

export type Prediction = {
  id?: string;
  user_id: string;
  match_id: string;
  predicted_home_score: number;
  predicted_away_score: number;
  points_earned: number | null;
  is_calculated: boolean;
};

export type Profile = {
  id: string;
  username: string;
  avatar_url: string | null;
  total_points: number;
  predictions_count: number;
  correct_predictions: number;
};

export type League = {
  id: string;
  name: string;
  invite_code: string;
  admin_id: string;
  entry_fee_gemings: number;
  created_at: string;
};

export type ChatRoom = {
  id: string;
  name: string;
  invite_code: string | null;
  created_by: string;
  avatar_url: string | null;
  match_id: string | null;
  league_id: string | null;
  created_at: string;
};

export type ChatMessage = {
  id: string;
  room_id: string;
  user_id: string;
  username: string;
  content: string;
  created_at: string;
};

/**
 * Gwarantuje, że zalogowany użytkownik ma wiersz w `profiles`.
 * Aplikacja Flutter tworzy profil ręcznie po rejestracji — web musi robić to samo,
 * inaczej nick się nie wyświetla, a typy nie zapisują się (FK predictions→profiles).
 * Zwraca username (z profilu lub utworzony).
 */
export async function ensureProfile(): Promise<{ id: string; username: string } | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: existing } = await supabase
    .from("profiles").select("id, username").eq("id", user.id).maybeSingle();

  if (existing?.username) return existing;

  // Brak profilu lub pusty nick — utwórz/uzupełnij
  const fallback =
    (user.user_metadata?.username as string | undefined) ||
    (user.email ? user.email.split("@")[0] : null) ||
    `gracz_${user.id.slice(0, 6)}`;

  const { data: created } = await supabase
    .from("profiles")
    .upsert({ id: user.id, username: fallback, is_premium: false }, { onConflict: "id" })
    .select("id, username").single();

  return created ?? { id: user.id, username: fallback };
}

// Kod zaproszenia: 6 znaków A-Z 0-9 (jak w aplikacji)
export function generateInviteCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

export function isLive(status: string) {
  return ["LIVE", "1H", "HT", "2H", "ET", "P"].includes(status);
}
export function isFinished(status: string) {
  return ["FT", "AET", "PEN"].includes(status);
}
export function isUpcoming(status: string) {
  return ["NS", "TBD", "scheduled", "upcoming"].includes(status);
}

export function formatMatchTime(isoString: string) {
  const d = new Date(isoString);
  return d.toLocaleDateString("pl-PL", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

// Opcjonalny tłumacz — gdy podany, lokalizuje CL/WC oraz fallback piłki nożnej.
export function competitionLabel(
  comp: string | null,
  sport: string,
  t?: (key: "comp.cl" | "comp.wc" | "comp.football") => string,
) {
  const map: Record<string, string> = {
    PL: "Premier League", BL1: "Bundesliga", SA: "Serie A",
    PD: "La Liga", FL1: "Ligue 1",
    CL: t ? t("comp.cl") : "Liga Mistrzów",
    EC: "Euro",
    WC: t ? t("comp.wc") : "MŚ",
  };
  return comp ? (map[comp] ?? comp) : sport === "football" ? (t ? t("comp.football") : "Piłka nożna") : sport;
}
