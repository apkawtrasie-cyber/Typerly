-- =============================================
-- FAZA GRUPOWA + DRABINKA PUCHAROWA (Etap 2)
-- =============================================

-- Grupy w turnieju (A, B, C, D ...)
create table if not exists tournament_groups (
  id            uuid default gen_random_uuid() primary key,
  tournament_id uuid references custom_tournaments on delete cascade not null,
  name          text not null,
  created_at    timestamptz default now(),
  unique(tournament_id, name)
);
create index if not exists tournament_groups_tid_idx on tournament_groups(tournament_id);

-- Przynależność drużyn do grup
create table if not exists group_team_assignments (
  group_id uuid references tournament_groups on delete cascade not null,
  team_id  uuid references custom_teams on delete cascade not null,
  primary key(group_id, team_id)
);
create index if not exists gta_group_idx on group_team_assignments(group_id);
create index if not exists gta_team_idx  on group_team_assignments(team_id);

-- Rozszerz tabelę meczów o kolumny fazy grupowej i drabinki
alter table custom_matches
  add column if not exists group_id        uuid references tournament_groups,
  add column if not exists match_phase     text not null default 'manual',
  add column if not exists knockout_round  integer,
  add column if not exists knockout_slot   integer,
  add column if not exists home_source     text,
  add column if not exists away_source     text;

-- match_phase: 'manual' | 'group' | 'knockout'

-- =============================================
-- RLS
-- =============================================
alter table tournament_groups       enable row level security;
alter table group_team_assignments  enable row level security;

create policy "Odczyt grup turnieju"
  on tournament_groups for select
  using (
    exists (
      select 1 from custom_tournaments ct
      left join tournament_members tm on tm.tournament_id = ct.id
      where ct.id = tournament_id
        and (ct.admin_id = auth.uid() or tm.user_id = auth.uid())
    )
  );

create policy "Admin zarządza grupami"
  on tournament_groups for all
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id and ct.admin_id = auth.uid()
    )
  );

create policy "Odczyt przypisań drużyn"
  on group_team_assignments for select
  using (
    exists (
      select 1 from tournament_groups tg
      join custom_tournaments ct on ct.id = tg.tournament_id
      left join tournament_members tm on tm.tournament_id = ct.id
      where tg.id = group_id
        and (ct.admin_id = auth.uid() or tm.user_id = auth.uid())
    )
  );

create policy "Admin zarządza przypisaniami drużyn"
  on group_team_assignments for all
  using (
    exists (
      select 1 from tournament_groups tg
      join custom_tournaments ct on ct.id = tg.tournament_id
      where tg.id = group_id and ct.admin_id = auth.uid()
    )
  );
