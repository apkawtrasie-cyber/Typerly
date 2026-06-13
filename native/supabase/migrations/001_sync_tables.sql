-- =============================================
-- TABELE
-- =============================================

-- Kolumna external_id w matches (do upsert)
alter table matches add column if not exists external_id text unique;
alter table matches add column if not exists competition text;

-- Składy drużyn
create table if not exists squads (
  id uuid default gen_random_uuid() primary key,
  team_id text not null,
  team_name text not null,
  player_id text,
  player_name text not null,
  player_position text,
  player_nationality text,
  player_age integer,
  player_photo_url text,
  updated_at timestamp with time zone default now()
);
create index if not exists squads_team_id_idx on squads(team_id);

-- Tabele ligowe
create table if not exists standings (
  id uuid default gen_random_uuid() primary key,
  competition text not null,
  position integer not null,
  team_id text not null,
  team_name text not null,
  team_logo_url text,
  played integer default 0,
  won integer default 0,
  draw integer default 0,
  lost integer default 0,
  goals_for integer default 0,
  goals_against integer default 0,
  goal_difference integer default 0,
  points integer default 0,
  updated_at timestamp with time zone default now()
);
create index if not exists standings_competition_idx on standings(competition);

-- Strzelcy
create table if not exists top_scorers (
  id uuid default gen_random_uuid() primary key,
  competition text not null,
  position integer not null,
  player_id text,
  player_name text not null,
  team_name text not null,
  goals integer default 0,
  assists integer default 0,
  updated_at timestamp with time zone default now()
);
create index if not exists top_scorers_competition_idx on top_scorers(competition);

-- =============================================
-- RLS - zezwól na odczyt dla zalogowanych
-- =============================================
alter table squads enable row level security;
alter table standings enable row level security;
alter table top_scorers enable row level security;

create policy "Odczyt dla zalogowanych" on squads for select using (auth.role() = 'authenticated');
create policy "Odczyt dla zalogowanych" on standings for select using (auth.role() = 'authenticated');
create policy "Odczyt dla zalogowanych" on top_scorers for select using (auth.role() = 'authenticated');

-- =============================================
-- pg_cron - automatyczne odpalanie
-- =============================================

-- Co godzinę - mecze
select cron.schedule(
  'sync-matches',
  '0 * * * *',
  $$
    select net.http_post(
      url := 'https://bgzyyhtjyhjwvklnpils.supabase.co/functions/v1/sync-matches',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      )
    );
  $$
);

-- Co 6 godzin - tabele i strzelcy
select cron.schedule(
  'sync-standings',
  '0 */6 * * *',
  $$
    select net.http_post(
      url := 'https://bgzyyhtjyhjwvklnpils.supabase.co/functions/v1/sync-standings',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      )
    );
  $$
);

-- Raz dziennie o 3:00 - składy
select cron.schedule(
  'sync-squads',
  '0 3 * * *',
  $$
    select net.http_post(
      url := 'https://bgzyyhtjyhjwvklnpils.supabase.co/functions/v1/sync-squads',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      )
    );
  $$
);
