-- =============================================
-- FIX: Brakujące polityki DELETE (RLS)
-- Bez nich Supabase po cichu odrzuca usuwanie (0 wierszy, bez błędu),
-- przez co nie działało: usuwanie turnieju, usuwanie ligi, opuszczanie grupy.
-- Zasada: twórca (admin) może usunąć to, co stworzył; członek może opuścić grupę.
-- =============================================

-- ── Turnieje ────────────────────────────────────────────────────────────────
drop policy if exists "Usuwanie turnieju przez admina" on custom_tournaments;
create policy "Usuwanie turnieju przez admina"
  on custom_tournaments for delete
  using (auth.uid() = admin_id);

-- Członek turnieju: może usunąć własne członkostwo (opuścić),
-- admin turnieju: może usunąć dowolnego członka.
drop policy if exists "Usuwanie członka turnieju" on tournament_members;
create policy "Usuwanie członka turnieju"
  on tournament_members for delete
  using (
    auth.uid() = user_id
    or exists (
      select 1 from custom_tournaments ct
      where ct.id = tournament_members.tournament_id
        and ct.admin_id = auth.uid()
    )
  );

-- ── Ligi ──────────────────────────────────────────────────────────────────--
drop policy if exists "Usuwanie ligi przez admina" on leagues;
create policy "Usuwanie ligi przez admina"
  on leagues for delete
  using (auth.uid() = admin_id);

-- Edycja ligi przez admina (gdyby brakowało) — potrzebne do zmiany nazwy.
drop policy if exists "Edycja ligi przez admina" on leagues;
create policy "Edycja ligi przez admina"
  on leagues for update
  using (auth.uid() = admin_id);

-- Członek ligi: może opuścić (usunąć własne członkostwo),
-- admin ligi: może usunąć dowolnego członka (potrzebne przy usuwaniu ligi).
drop policy if exists "Usuwanie członka ligi" on league_members;
create policy "Usuwanie członka ligi"
  on league_members for delete
  using (
    auth.uid() = user_id
    or exists (
      select 1 from leagues l
      where l.id = league_members.league_id
        and l.admin_id = auth.uid()
    )
  );
