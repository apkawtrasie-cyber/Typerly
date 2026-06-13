// Edge Function: sync-live
// Używa api-football.com (/fixtures?live=all) — 1 request na wywołanie.
// Free tier: 100 req/dzień → cron co 20 minut = max 72 req/dzień.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const API_SPORTS_KEY = Deno.env.get('API_FOOTBALL_KEY') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

Deno.serve(async () => {
  if (!API_SPORTS_KEY) {
    return new Response(JSON.stringify({ error: 'Missing API_FOOTBALL_KEY' }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    })
  }

  try {
    const now = new Date()
    const yesterday = new Date(now.getTime() - 86400000).toISOString().slice(0, 10)
    const today = now.toISOString().slice(0, 10)

    // Jeden request: wszystkie aktualnie live mecze
    const res = await fetch('https://v3.football.api-sports.io/fixtures?live=all', {
      headers: { 'x-apisports-key': API_SPORTS_KEY },
    })

    if (!res.ok) {
      return new Response(JSON.stringify({ error: `API HTTP ${res.status}` }), {
        status: 502, headers: { 'Content-Type': 'application/json' },
      })
    }

    const data = await res.json()

    // Sprawdź czy konto nie jest zawieszone
    if (data.errors?.access) {
      return new Response(JSON.stringify({ error: data.errors.access }), {
        status: 402, headers: { 'Content-Type': 'application/json' },
      })
    }

    const fixtures: any[] = data.response ?? []
    let liveUpdated = 0
    const errors: string[] = []

    // Ustaw wszystkie wcześniej LIVE mecze z dnia dzisiejszego na NS (reset)
    // żeby mecze które się skończyły wróciły do normalnego stanu
    // (sync-matches co 10 min zaktualizuje je na FT)
    await supabase
      .from('matches')
      .update({ status: 'NS' })
      .eq('status', 'LIVE')
      .gte('match_time', `${yesterday}T00:00:00`)
      .lte('match_time', `${today}T23:59:59`)

    // Zaktualizuj aktualnie live mecze
    for (const f of fixtures) {
      const home = f.teams?.home?.name as string | undefined
      const away = f.teams?.away?.name as string | undefined
      if (!home || !away) continue

      const { error } = await supabase
        .from('matches')
        .update({
          status: 'LIVE',
          home_score: f.goals?.home ?? null,
          away_score: f.goals?.away ?? null,
        })
        .ilike('home_team_name', home)
        .ilike('away_team_name', away)
        .gte('match_time', `${yesterday}T00:00:00`)
        .lte('match_time', `${today}T23:59:59`)

      if (error) errors.push(`${home} vs ${away}: ${error.message}`)
      else liveUpdated++
    }

    return new Response(
      JSON.stringify({ success: true, liveMatches: fixtures.length, liveUpdated, errors, ts: now.toISOString() }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    })
  }
})
