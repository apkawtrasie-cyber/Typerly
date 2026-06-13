-- Rozdzielenie czatu meczu per kontekst:
--   league_id NULL  → czat globalny (zakładka Mecze, widoczny dla wszystkich)
--   league_id = X   → czat prywatnej ligi (tylko jej członkowie wchodzą tam
--                     przez szczegóły meczu otwarte z poziomu ligi)

alter table chat_rooms
  add column if not exists league_id uuid references leagues(id) on delete cascade;

-- Stary indeks dopuszczał tylko jeden pokój na mecz — zastępujemy go parą:
drop index if exists chat_rooms_match_id_key;

-- Jeden pokój globalny na mecz
create unique index if not exists chat_rooms_match_global_key
  on chat_rooms (match_id)
  where match_id is not null and league_id is null;

-- Jeden pokój na mecz w obrębie danej ligi
create unique index if not exists chat_rooms_match_league_key
  on chat_rooms (match_id, league_id)
  where match_id is not null and league_id is not null;
