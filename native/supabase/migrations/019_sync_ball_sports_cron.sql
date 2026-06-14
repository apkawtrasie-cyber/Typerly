-- Harmonogram dla siatkówki i piłki ręcznej (Edge Function sync-ball-sports).
-- Co 3 godziny: okno 7 dni × 2 sporty. api-sports Free = 100 żądań/dobę OSOBNO
-- na produkt (volleyball, handball). 8 wywołań/dobę × 7 dni = 56 żądań/sport/dobę
-- → bezpiecznie poniżej limitu 100.

select cron.schedule(
  'sync-ball-sports',
  '0 */3 * * *',
  $$
    select net.http_post(
      url := 'https://bgzyyhtjyhjwvklnpils.supabase.co/functions/v1/sync-ball-sports',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      )
    );
  $$
);
