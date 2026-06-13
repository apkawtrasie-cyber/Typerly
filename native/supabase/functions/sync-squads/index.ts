// Edge Function: sync-squads
// Pobiera kadry drużyn z football-data.org (/v4/teams/{id}) i zapisuje do Supabase.
// TheSportsDB odpadł: darmowy klucz zwraca maks. 10 osób na drużynę.
// Drużyny dobierane dynamicznie z tabeli matches — najpierw te, które grają najbliżej.
// Jedno wywołanie odświeża jedną ligę i do MAX_TEAMS_PER_RUN drużyn (limit 10 req/min
// football-data + limit czasu funkcji). pg_cron raz dziennie; można wołać częściej.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FOOTBALL_DATA_API_KEY = Deno.env.get('FOOTBALL_DATA_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

const MAX_TEAMS_PER_RUN = 12
const FRESH_DAYS = 7          // kadra młodsza niż tyle dni → pomijana
const MATCH_WINDOW_DAYS = 30  // kadry tylko drużyn grających w tym oknie
const API_DELAY_MS = 6500     // football-data free: 10 żądań/min

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

async function fdFetch(path: string) {
  const res = await fetch(`https://api.football-data.org/v4${path}`, {
    headers: { 'X-Auth-Token': FOOTBALL_DATA_API_KEY },
  })
  if (!res.ok) throw new Error(`football-data ${path}: HTTP ${res.status}`)
  return res.json()
}

Deno.serve(async () => {
  try {
    const now = Date.now()
    const day = 24 * 60 * 60 * 1000
    const from = new Date(now - 1 * day).toISOString()
    const to = new Date(now + MATCH_WINDOW_DAYS * day).toISOString()

    // 1. Drużyny z nadchodzących meczów (posortowane: najbliższy mecz najpierw)
    const { data: matches, error: mErr } = await supabase
      .from('matches')
      .select('home_team_name, away_team_name, match_time, competition')
      .eq('is_custom', false)
      .not('competition', 'is', null)
      .gte('match_time', from)
      .lte('match_time', to)
      .order('match_time')

    if (mErr) throw new Error(`matches: ${mErr.message}`)

    // team_name → { competition, nextMatch } (pierwsze wystąpienie = najwcześniejszy mecz)
    const teams = new Map<string, { competition: string; nextMatch: string }>()
    for (const m of matches ?? []) {
      for (const name of [m.home_team_name, m.away_team_name]) {
        if (name && !teams.has(name)) {
          teams.set(name, { competition: m.competition, nextMatch: m.match_time })
        }
      }
    }

    // 2. Świeżość kadr — pomijamy drużyny zaktualizowane w ciągu FRESH_DAYS
    const { data: existing } = await supabase
      .from('squads')
      .select('team_name, updated_at')
    const freshCutoff = now - FRESH_DAYS * day
    const lastUpdate = new Map<string, number>()
    for (const row of existing ?? []) {
      const t = new Date(row.updated_at).getTime()
      const prev = lastUpdate.get(row.team_name) ?? 0
      if (t > prev) lastUpdate.set(row.team_name, t)
    }

    const stale = [...teams.entries()]
      .filter(([name]) => (lastUpdate.get(name) ?? 0) < freshCutoff)
      .map(([name, info]) => ({ name, ...info }))

    if (stale.length === 0) {
      return new Response(
        JSON.stringify({ success: true, synced: 0, stale: 0, message: 'Wszystkie kadry świeże' }),
        { headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 3. Jedna liga na wywołanie — ta, w której ktoś gra najbliżej
    const competition = stale[0].competition
    const batch = stale
      .filter((t) => t.competition === competition)
      .slice(0, MAX_TEAMS_PER_RUN)

    // 4. Mapa nazwa → id drużyny w tej lidze (1 żądanie)
    const compTeams = await fdFetch(`/competitions/${competition}/teams`)
    const idByName = new Map<string, number>()
    for (const t of compTeams.teams ?? []) idByName.set(t.name, t.id)
    await sleep(API_DELAY_MS)

    // 5. Kadry drużyn z paczki
    let totalSynced = 0
    const errors: string[] = []

    for (const team of batch) {
      const teamId = idByName.get(team.name)
      if (!teamId) {
        errors.push(`${team.name}: brak w /competitions/${competition}/teams`)
        continue
      }

      try {
        const detail = await fdFetch(`/teams/${teamId}`)
        const squad = detail.squad ?? []

        const rows = squad.map((p: any) => ({
          team_id: String(teamId),
          // Nazwa identyczna jak w matches — po niej aplikacja łączy skład z meczem
          team_name: team.name,
          player_id: p.id != null ? String(p.id) : null,
          player_name: p.name,
          player_position: p.position ?? null,
          player_nationality: p.nationality ?? null,
          player_age: p.dateOfBirth
            ? Math.floor((now - new Date(p.dateOfBirth).getTime()) / (365.25 * day))
            : null,
          player_photo_url: null,
          updated_at: new Date().toISOString(),
        }))

        if (rows.length > 0) {
          await supabase.from('squads').delete().eq('team_name', team.name)
          const { error } = await supabase.from('squads').insert(rows)
          if (error) errors.push(`${team.name} insert: ${error.message}`)
          else totalSynced += rows.length
        }
      } catch (err) {
        errors.push(`${team.name}: ${(err as Error).message}`)
      }

      await sleep(API_DELAY_MS)
    }

    return new Response(
      JSON.stringify({
        success: true,
        competition,
        teams: batch.length,
        synced: totalSynced,
        stale: stale.length - batch.length,
        errors,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
