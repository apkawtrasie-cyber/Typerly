// Edge Function: sync-ball-sports
// Pobiera mecze siatkówki i piłki ręcznej z api-sports.io i zapisuje do tabeli matches.
// Oba sporty pasują do modelu dom:gość (siatkówka = sety, piłka ręczna = bramki),
// więc używają tej samej tabeli i ekranu typowania co piłka nożna.
//
// LIMITY: api-sports Free = 100 żądań/dobę OSOBNO dla każdego produktu
// (v1.volleyball i v1.handball mają niezależne liczniki). Jedno wywołanie =
// (liczba dni w oknie) żądań na sport. Okno 7 dni = 7 żądań/sport/wywołanie.
// pg_cron co 3h = 8 wywołań/dobę = 56 żądań/sport/dobę → bezpiecznie < 100.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const API_KEY = Deno.env.get('API_FOOTBALL_KEY') ?? '' // ten sam klucz api-sports dla wszystkich produktów
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// Okno: wczoraj + 5 dni w przód (7 dni). Wczoraj — żeby dociągnąć końcowe wyniki.
const WINDOW_PAST_DAYS = 1
const WINDOW_FUTURE_DAYS = 5

type SportCfg = { host: string; sport: string; prefix: string }
const SPORTS: SportCfg[] = [
  { host: 'v1.volleyball.api-sports.io', sport: 'volleyball', prefix: 'vb' },
  { host: 'v1.handball.api-sports.io', sport: 'handball', prefix: 'hb' },
]

// Mapowanie statusów api-sports → kody rozumiane przez web/Flutter (isLive/isFinished/isUpcoming)
function mapStatus(short: string): string {
  const s = (short ?? '').toUpperCase()
  if (['NS', 'TBD'].includes(s)) return 'NS'
  if (['FT', 'AOT', 'AET', 'PEN'].includes(s)) return 'FT'
  if (s === 'POST') return 'PST'
  if (['CANC', 'ABD', 'WO', 'AWD'].includes(s)) return 'CANC'
  return 'LIVE' // S1-S5, 1H, 2H, HT, ET, LIVE, P... — mecz w trakcie
}

function dateList(): string[] {
  const out: string[] = []
  const day = 24 * 60 * 60 * 1000
  const now = Date.now()
  for (let i = -WINDOW_PAST_DAYS; i <= WINDOW_FUTURE_DAYS; i++) {
    out.push(new Date(now + i * day).toISOString().slice(0, 10))
  }
  return out
}

Deno.serve(async () => {
  try {
    const errors: string[] = []
    let totalSynced = 0
    const dates = dateList()

    for (const cfg of SPORTS) {
      const rows: Record<string, unknown>[] = []
      const seen = new Set<string>()

      for (const date of dates) {
        const res = await fetch(`https://${cfg.host}/games?date=${date}`, {
          headers: { 'x-apisports-key': API_KEY },
        })
        if (!res.ok) {
          errors.push(`${cfg.sport} ${date}: HTTP ${res.status}`)
          continue
        }
        const data = await res.json()
        const games: any[] = data.response ?? []

        for (const g of games) {
          const home = g?.teams?.home?.name
          const away = g?.teams?.away?.name
          if (!home || !away) continue
          const extId = `${cfg.prefix}-${g.id}`
          if (seen.has(extId)) continue
          seen.add(extId)
          rows.push({
            external_id: extId,
            home_team_name: home,
            away_team_name: away,
            home_team_logo_url: g?.teams?.home?.logo ?? null,
            away_team_logo_url: g?.teams?.away?.logo ?? null,
            match_time: g?.date,
            status: mapStatus(g?.status?.short),
            home_score: g?.scores?.home ?? null,
            away_score: g?.scores?.away ?? null,
            sport_type: cfg.sport,
            is_custom: false,
            competition: g?.league?.name ?? null,
          })
        }
        // Lekka pauza między żądaniami (api-sports: ~10/min na produkt)
        await new Promise((r) => setTimeout(r, 1200))
      }

      if (rows.length > 0) {
        const { error } = await supabase.from('matches').upsert(rows, { onConflict: 'external_id' })
        if (error) errors.push(`${cfg.sport} upsert: ${error.message}`)
        else totalSynced += rows.length
      }
    }

    return new Response(JSON.stringify({ success: true, synced: totalSynced, errors }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
