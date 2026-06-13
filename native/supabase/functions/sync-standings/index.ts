// Edge Function: sync-standings
// Pobiera tabele ligowe i strzelców z football-data.org
// Uruchamiana przez pg_cron co 6 godzin

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FOOTBALL_DATA_API_KEY = Deno.env.get('FOOTBALL_DATA_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

const COMPETITIONS = ['PL', 'PD', 'BL1', 'SA', 'FL1']

Deno.serve(async () => {
  try {
    let totalSynced = 0

    for (const competition of COMPETITIONS) {
      // Pobierz tabelę
      const standingsRes = await fetch(
        `https://api.football-data.org/v4/competitions/${competition}/standings`,
        { headers: { 'X-Auth-Token': FOOTBALL_DATA_API_KEY } }
      )

      if (standingsRes.ok) {
        const data = await standingsRes.json()
        const table = data.standings?.[0]?.table ?? []

        // Usuń starą tabelę
        await supabase.from('standings').delete().eq('competition', competition)

        // Wstaw nową
        const rows = table.map((row: any) => ({
          competition,
          position: row.position,
          team_id: String(row.team.id),
          team_name: row.team.name,
          team_logo_url: row.team.crest ?? null,
          played: row.playedGames,
          won: row.won,
          draw: row.draw,
          lost: row.lost,
          goals_for: row.goalsFor,
          goals_against: row.goalsAgainst,
          goal_difference: row.goalDifference,
          points: row.points,
          updated_at: new Date().toISOString(),
        }))

        if (rows.length > 0) {
          await supabase.from('standings').insert(rows)
          totalSynced += rows.length
        }
      }

      // Pobierz strzelców
      const scorersRes = await fetch(
        `https://api.football-data.org/v4/competitions/${competition}/scorers?limit=20`,
        { headers: { 'X-Auth-Token': FOOTBALL_DATA_API_KEY } }
      )

      if (scorersRes.ok) {
        const data = await scorersRes.json()
        const scorers = data.scorers ?? []

        await supabase.from('top_scorers').delete().eq('competition', competition)

        const rows = scorers.map((s: any, i: number) => ({
          competition,
          position: i + 1,
          player_id: String(s.player.id),
          player_name: s.player.name,
          team_name: s.team.name,
          goals: s.goals ?? 0,
          assists: s.assists ?? 0,
          updated_at: new Date().toISOString(),
        }))

        if (rows.length > 0) {
          await supabase.from('top_scorers').insert(rows)
          totalSynced += rows.length
        }
      }
    }

    return new Response(JSON.stringify({ success: true, synced: totalSynced }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
