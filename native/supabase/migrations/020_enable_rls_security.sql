-- =============================================
-- BEZPIECZEŃSTWO: włącz RLS na tabelach, które miały polityki, ale RLS był wyłączony.
-- Bez tego tabele były "UNRESTRICTED" — każdy z kluczem anon mógł je czytać I ZAPISYWAĆ.
--
-- Uwaga: synchronizacja meczów (Edge Functions) używa klucza service_role,
-- który OMIJA RLS — więc import wyników działa dalej bez zmian.
-- Piłka nożna i cała logika nietknięte — to tylko kontrola dostępu.
-- =============================================

-- ── matches: publiczne dane sportowe ────────────────────────────────────────
-- Odczyt dla wszystkich, zapis tylko przez service_role (Edge Functions).
alter table matches enable row level security;

drop policy if exists "Odczyt meczów" on matches;
create policy "Odczyt meczów"
  on matches for select
  using (true);

-- ── leagues ─────────────────────────────────────────────────────────────────
-- Odczyt dla zalogowanych (potrzebny do dołączania po kodzie),
-- tworzenie własnej ligi; edycja/usuwanie przez admina już istnieją (migracja 014).
alter table leagues enable row level security;

drop policy if exists "Odczyt lig dla zalogowanych" on leagues;
create policy "Odczyt lig dla zalogowanych"
  on leagues for select
  using (auth.uid() is not null);

drop policy if exists "Tworzenie ligi" on leagues;
create policy "Tworzenie ligi"
  on leagues for insert
  with check (auth.uid() = admin_id);

-- ── league_members ───────────────────────────────────────────────────────────
-- Polityki select/insert/delete już istnieją (migracje 007, 008, 014).
-- Wystarczy włączyć RLS.
alter table league_members enable row level security;
