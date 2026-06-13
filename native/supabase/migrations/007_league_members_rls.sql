-- =============================================
-- FIX: RLS dla league_members
-- Użytkownicy mogą widzieć wszystkich członków lig, do których należą
-- =============================================

-- Usuń ewentualne wcześniejsze restrykcyjne polityki
drop policy if exists "View own membership" on league_members;
drop policy if exists "Users can view their own league memberships" on league_members;
drop policy if exists "Odczyt własnych członkostw" on league_members;

-- Zezwól każdemu członkowi ligi na widzenie wszystkich innych członków tej ligi
drop policy if exists "Odczyt członków ligi dla członków" on league_members;
create policy "Odczyt członków ligi dla członków"
  on league_members for select
  using (
    exists (
      select 1 from league_members lm2
      where lm2.league_id = league_members.league_id
        and lm2.user_id = auth.uid()
    )
  );

-- Zezwól na wstawianie własnego członkostwa
drop policy if exists "Dołączanie do ligi" on league_members;
create policy "Dołączanie do ligi"
  on league_members for insert
  with check (auth.uid() = user_id);
