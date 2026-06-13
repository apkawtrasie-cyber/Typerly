-- Stara polityka była rekurencyjna (sprawdzała tournament_members w sobie) → 403
-- Zastępujemy prostą: każdy widzi swoje własne wiersze
drop policy if exists "Odczyt członków turnieju" on tournament_members;

create policy "Odczyt własnych członkostw turnieju"
  on tournament_members for select
  using (auth.uid() = user_id);

-- Admin turnieju też musi widzieć wszystkich członków (dla generowania drabinki itp.)
create policy "Admin widzi członków swojego turnieju"
  on tournament_members for select
  using (
    exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_id and ct.admin_id = auth.uid()
    )
  );
