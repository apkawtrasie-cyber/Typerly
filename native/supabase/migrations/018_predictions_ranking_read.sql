-- Pozwól zalogowanym użytkownikom czytać punkty (tylko punkty) innych graczy
-- potrzebne do budowania globalnego rankingu
create policy "Odczyt punktów innych graczy"
  on predictions for select
  using (auth.uid() is not null);
