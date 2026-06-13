-- =============================================
-- PRYWATNE TURNIEJE WŁASNE (Etap 1)
-- =============================================

-- Turnieje tworzone przez użytkowników
create table if not exists custom_tournaments (
  id              uuid default gen_random_uuid() primary key,
  name            text not null,
  admin_id        uuid references auth.users not null,
  invite_code     text unique not null,
  prize_description text,
  created_at      timestamptz default now()
);
create index if not exists custom_tournaments_admin_idx on custom_tournaments(admin_id);

-- Drużyny w turnieju (własne, spoza football-data.org)
create table if not exists custom_teams (
  id              uuid default gen_random_uuid() primary key,
  tournament_id   uuid references custom_tournaments on delete cascade not null,
  name            text not null,
  logo_url        text,
  created_at      timestamptz default now()
);
create index if not exists custom_teams_tournament_idx on custom_teams(tournament_id);

-- Mecze turnieju (między custom_teams, wynik wpisuje admin ręcznie)
create table if not exists custom_matches (
  id              uuid default gen_random_uuid() primary key,
  tournament_id   uuid references custom_tournaments on delete cascade not null,
  home_team_id    uuid references custom_teams not null,
  away_team_id    uuid references custom_teams not null,
  home_team_name  text not null,
  away_team_name  text not null,
  home_team_logo  text,
  away_team_logo  text,
  match_time      timestamptz not null,
  status          text not null default 'NS',  -- NS / LIVE / FT
  home_score      integer,
  away_score      integer,
  round_name      text,  -- np. 'Faza grupowa', 'Ćwierćfinał', 'Finał'
  created_at      timestamptz default now()
);
create index if not exists custom_matches_tournament_idx on custom_matches(tournament_id);
create index if not exists custom_matches_time_idx on custom_matches(match_time);

-- Członkowie turnieju
create table if not exists tournament_members (
  id              uuid default gen_random_uuid() primary key,
  tournament_id   uuid references custom_tournaments on delete cascade not null,
  user_id         uuid references auth.users not null,
  joined_at       timestamptz default now(),
  unique(tournament_id, user_id)
);
create index if not exists tournament_members_tournament_idx on tournament_members(tournament_id);
create index if not exists tournament_members_user_idx on tournament_members(user_id);

-- Typy na mecze turnieju (osobna tabela żeby nie mieszać z globalnymi typami)
create table if not exists tournament_predictions (
  id                    uuid default gen_random_uuid() primary key,
  tournament_id         uuid references custom_tournaments on delete cascade not null,
  custom_match_id       uuid references custom_matches on delete cascade not null,
  user_id               uuid references auth.users not null,
  predicted_home_score  integer not null,
  predicted_away_score  integer not null,
  points_earned         integer not null default 0,
  is_calculated         boolean not null default false,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now(),
  unique(custom_match_id, user_id)
);
create index if not exists tournament_predictions_match_idx on tournament_predictions(custom_match_id);
create index if not exists tournament_predictions_user_idx on tournament_predictions(user_id);
create index if not exists tournament_predictions_tournament_idx on tournament_predictions(tournament_id);

-- =============================================
-- Trigger: naliczaj punkty gdy admin wpisze wynik
-- =============================================
create or replace function score_tournament_predictions(p_match_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_home  integer;
  v_away  integer;
  v_count integer;
begin
  select home_score, away_score into v_home, v_away
    from custom_matches where id = p_match_id;

  if v_home is null or v_away is null then return 0; end if;

  update tournament_predictions
     set points_earned = calculate_match_points(
                           predicted_home_score, predicted_away_score,
                           v_home, v_away),
         is_calculated = true,
         updated_at    = now()
   where custom_match_id = p_match_id;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function trigger_score_tournament_predictions()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.status = 'FT'
     and new.home_score is not null
     and new.away_score is not null
     and (old.status is distinct from 'FT'
          or old.home_score is distinct from new.home_score
          or old.away_score is distinct from new.away_score)
  then
    perform score_tournament_predictions(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_score_tournament_predictions on custom_matches;
create trigger trg_score_tournament_predictions
  after update on custom_matches
  for each row execute function trigger_score_tournament_predictions();

-- =============================================
-- RLS
-- =============================================
alter table custom_tournaments     enable row level security;
alter table custom_teams           enable row level security;
alter table custom_matches         enable row level security;
alter table tournament_members     enable row level security;
alter table tournament_predictions enable row level security;

-- Turnieje: widoczne dla członków i admina
create policy "Odczyt turnieju dla członka"
  on custom_tournaments for select
  using (
    auth.uid() = admin_id
    or exists (
      select 1 from tournament_members tm
      where tm.tournament_id = id and tm.user_id = auth.uid()
    )
  );

create policy "Tworzenie turnieju"
  on custom_tournaments for insert
  with check (auth.uid() = admin_id);

create policy "Edycja turnieju przez admina"
  on custom_tournaments for update
  using (auth.uid() = admin_id);

-- Drużyny: widoczne dla członków turnieju
create policy "Odczyt drużyn turnieju"
  on custom_teams for select
  using (
    exists (
      select 1 from custom_tournaments ct
      left join tournament_members tm on tm.tournament_id = ct.id
      where ct.id = tournament_id
        and (ct.admin_id = auth.uid() or tm.user_id = auth.uid())
    )
  );

create policy "Admin zarządza drużynami"
  on custom_teams for all
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id and ct.admin_id = auth.uid()
    )
  );

-- Mecze: widoczne dla członków
create policy "Odczyt meczów turnieju"
  on custom_matches for select
  using (
    exists (
      select 1 from custom_tournaments ct
      left join tournament_members tm on tm.tournament_id = ct.id
      where ct.id = tournament_id
        and (ct.admin_id = auth.uid() or tm.user_id = auth.uid())
    )
  );

create policy "Admin zarządza meczami"
  on custom_matches for all
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id and ct.admin_id = auth.uid()
    )
  );

-- Członkowie
create policy "Odczyt członków turnieju"
  on tournament_members for select
  using (
    exists (
      select 1 from tournament_members tm2
      where tm2.tournament_id = tournament_id and tm2.user_id = auth.uid()
    )
  );

create policy "Dołączanie do turnieju"
  on tournament_members for insert
  with check (auth.uid() = user_id);

-- Typy turniejowe
create policy "Odczyt typów turnieju"
  on tournament_predictions for select
  using (
    exists (
      select 1 from tournament_members tm
      where tm.tournament_id = tournament_predictions.tournament_id
        and tm.user_id = auth.uid()
    )
  );

create policy "Zapis własnych typów turnieju"
  on tournament_predictions for insert
  with check (auth.uid() = user_id);

create policy "Modyfikacja własnych typów turnieju"
  on tournament_predictions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
