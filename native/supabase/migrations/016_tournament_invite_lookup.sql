-- Pozwól zalogowanemu użytkownikowi znaleźć turniej po kodzie zaproszenia
-- (potrzebne zanim zostanie członkiem i zanim RLS "Odczyt turnieju dla członka" zadziała)
create policy "Wyszukiwanie turnieju po kodzie zaproszenia"
  on custom_tournaments for select
  using (auth.uid() is not null);
