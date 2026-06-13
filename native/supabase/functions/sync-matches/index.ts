// Edge Function: sync-matches
// Pobiera mecze z football-data.org i zapisuje do Supabase
// Uruchamiana przez pg_cron co 1 godzinę

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FOOTBALL_DATA_API_KEY = Deno.env.get('FOOTBALL_DATA_API_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// Ligi do pobrania (kody football-data.org)
const COMPETITIONS = ['WC', 'CL', 'PL', 'SA', 'BL1', 'DED', 'BSA', 'PD', 'FL1', 'ELC', 'PPL']

// Okno czasowe zgodne z aplikacją (home_screen): 90 dni historii + 60 dni w przód
const WINDOW_PAST_DAYS = 90
const WINDOW_FUTURE_DAYS = 60

Deno.serve(async () => {
  try {
    let totalSynced = 0
    const errors: string[] = []

    const now = Date.now()
    const day = 24 * 60 * 60 * 1000
    const dateFrom = new Date(now - WINDOW_PAST_DAYS * day).toISOString().slice(0, 10)
    const dateTo = new Date(now + WINDOW_FUTURE_DAYS * day).toISOString().slice(0, 10)

    for (const competition of COMPETITIONS) {
      // Bez filtra statusów — pobieramy też FINISHED, żeby mecze dostawały
      // status FT i końcowy wynik (wcześniej zakończone nigdy nie wracały z API)
      const res = await fetch(
        `https://api.football-data.org/v4/competitions/${competition}/matches?dateFrom=${dateFrom}&dateTo=${dateTo}`,
        { headers: { 'X-Auth-Token': FOOTBALL_DATA_API_KEY } }
      )

      if (!res.ok) {
        console.error(`Błąd dla ${competition}: ${res.status}`)
        errors.push(`${competition}: HTTP ${res.status}`)
        continue
      }

      const data = await res.json()
      const matches = data.matches ?? []

      const rows = matches
        // Mecze fazy pucharowej bez ustalonych drużyn (TBD) pomijamy
        .filter((m: any) => m.homeTeam?.name && m.awayTeam?.name)
        .map((m: any) => ({
          external_id: String(m.id),
          home_team_name: m.homeTeam.name,
          away_team_name: m.awayTeam.name,
          home_team_logo_url: m.homeTeam.crest ?? null,
          away_team_logo_url: m.awayTeam.crest ?? null,
          match_time: m.utcDate,
          status: mapStatus(m.status),
          home_score: m.score?.fullTime?.home ?? null,
          away_score: m.score?.fullTime?.away ?? null,
          sport_type: 'football',
          is_custom: false,
          competition: competition,
        }))

      if (rows.length > 0) {
        const { error } = await supabase
          .from('matches')
          .upsert(rows, { onConflict: 'external_id' })
        if (error) {
          console.error(`Upsert ${competition}: ${error.message}`)
          errors.push(`${competition} upsert: ${error.message}`)
        } else {
          totalSynced += rows.length
        }
      }

      // football-data.org free tier: 10 żądań/min
      await new Promise((r) => setTimeout(r, 6500))
    }

    // Usuń mecze API starsze niż okno historii (aplikacja pokazuje 90 dni)
    const cutoff = new Date(now - WINDOW_PAST_DAYS * day).toISOString()
    await supabase
      .from('matches')
      .delete()
      .eq('is_custom', false)
      .not('external_id', 'is', null)
      .lt('match_time', cutoff)

    return new Response(JSON.stringify({ success: true, synced: totalSynced, errors }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})

function mapStatus(status: string): string {
  switch (status) {
    case 'SCHEDULED':
    case 'TIMED': return 'NS'
    case 'IN_PLAY':
    case 'PAUSED': return 'LIVE'
    case 'FINISHED':
    case 'AWARDED': return 'FT'
    case 'POSTPONED':
    case 'SUSPENDED': return 'PST'
    case 'CANCELLED': return 'CANC'
    default: return 'NS'
  }
}
