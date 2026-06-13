-- =============================================
-- FIX: Tylko JEDEN typ na (użytkownik, mecz, kontekst ligi)
-- Bez tego można było dodać typ kilka razy (brak ograniczenia w bazie).
-- league_id NULL = typ globalny; NULL nie jest unikalny w zwykłym indeksie,
-- dlatego dwa osobne indeksy częściowe.
-- =============================================

-- 1) Usuń istniejące duplikaty — zostaw najstarszy wpis w każdej grupie
--    (po user_id, match_id oraz league_id traktując NULL jako wspólną grupę).
delete from predictions p
using predictions q
where p.user_id = q.user_id
  and p.match_id = q.match_id
  and p.league_id is not distinct from q.league_id
  and p.ctid > q.ctid;

-- 2) Unikalny indeks dla typów GRUPOWYCH (league_id ustawione)
drop index if exists predictions_uniq_league;
create unique index predictions_uniq_league
  on predictions (user_id, match_id, league_id)
  where league_id is not null;

-- 3) Unikalny indeks dla typów GLOBALNYCH (league_id NULL)
drop index if exists predictions_uniq_global;
create unique index predictions_uniq_global
  on predictions (user_id, match_id)
  where league_id is null;
