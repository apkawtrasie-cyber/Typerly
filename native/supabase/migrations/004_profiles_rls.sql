-- Pozwól zalogowanym użytkownikom czytać profile innych (potrzebne do rankingów i list ligi)
-- Bez tego zapytanie profiles(username, avatar_url) zwraca null dla cudzych profili.

drop policy if exists "Public profiles are viewable by everyone." on profiles;
drop policy if exists "Profiles are viewable by authenticated users" on profiles;
drop policy if exists "Odczyt profili dla zalogowanych" on profiles;

create policy "Odczyt profili dla zalogowanych"
  on profiles for select
  using (auth.role() = 'authenticated');
