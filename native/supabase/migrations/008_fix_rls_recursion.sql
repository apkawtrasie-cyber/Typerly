-- =============================================
-- FIX: Infinite recursion w RLS tournament_members i league_members
-- Używamy security definer functions zamiast self-referencing policies
-- =============================================

-- Funkcja pomocnicza: sprawdź czy użytkownik jest członkiem turnieju (omija RLS)
create or replace function auth_is_tournament_member(p_tournament_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from tournament_members
    where tournament_id = p_tournament_id
      and user_id = auth.uid()
  );
$$;

-- Funkcja pomocnicza: sprawdź czy użytkownik jest członkiem ligi (omija RLS)
create or replace function auth_is_league_member(p_league_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from league_members
    where league_id = p_league_id
      and user_id = auth.uid()
  );
$$;

-- Napraw tournament_members: usuń rekurencyjną policy
drop policy if exists "Odczyt członków turnieju" on tournament_members;
create policy "Odczyt członków turnieju"
  on tournament_members for select
  using (auth_is_tournament_member(tournament_id));

-- Napraw league_members: usuń rekurencyjną policy
drop policy if exists "Odczyt członków ligi dla członków" on league_members;
create policy "Odczyt członków ligi dla członków"
  on league_members for select
  using (auth_is_league_member(league_id));

-- Napraw też custom_tournaments policy która też może triggerować rekursję
drop policy if exists "Odczyt turnieju dla członka" on custom_tournaments;
create policy "Odczyt turnieju dla członka"
  on custom_tournaments for select
  using (
    auth.uid() = admin_id
    or auth_is_tournament_member(id)
  );

-- Napraw custom_teams policy
drop policy if exists "Odczyt drużyn turnieju" on custom_teams;
create policy "Odczyt drużyn turnieju"
  on custom_teams for select
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id
        and (ct.admin_id = auth.uid() or auth_is_tournament_member(ct.id))
    )
  );

-- Napraw custom_matches policy
drop policy if exists "Odczyt meczów turnieju" on custom_matches;
create policy "Odczyt meczów turnieju"
  on custom_matches for select
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id
        and (ct.admin_id = auth.uid() or auth_is_tournament_member(ct.id))
    )
  );

-- Napraw tournament_predictions policy
drop policy if exists "Odczyt typów turnieju" on tournament_predictions;
create policy "Odczyt typów turnieju"
  on tournament_predictions for select
  using (auth_is_tournament_member(tournament_id));

-- Napraw tournament_groups policy
drop policy if exists "Odczyt grup turnieju" on tournament_groups;
create policy "Odczyt grup turnieju"
  on tournament_groups for select
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id
        and (ct.admin_id = auth.uid() or auth_is_tournament_member(ct.id))
    )
  );

-- Napraw group_team_assignments policy
drop policy if exists "Odczyt przypisań drużyn" on group_team_assignments;
create policy "Odczyt przypisań drużyn"
  on group_team_assignments for select
  using (
    exists (
      select 1 from tournament_groups tg
      join custom_tournaments ct on ct.id = tg.tournament_id
      where tg.id = group_id
        and (ct.admin_id = auth.uid() or auth_is_tournament_member(ct.id))
    )
  );
