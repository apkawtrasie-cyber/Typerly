-- Czat meczu: jeden pokój czatu per mecz, wspólny dla wszystkich typujących.
-- Pokój tworzony leniwie przy pierwszym otwarciu sekcji czatu w szczegółach
-- meczu (get-or-create po match_id). Zwykłe pokoje grupowe mają match_id NULL.

alter table chat_rooms
  add column if not exists match_id uuid references matches(id) on delete cascade;

-- Jeden pokój na mecz (częściowy unikalny indeks — NULL-e się nie liczą)
create unique index if not exists chat_rooms_match_id_key
  on chat_rooms (match_id)
  where match_id is not null;

-- Szybkie wyszukiwanie pokoju meczu
create index if not exists chat_rooms_match_id_idx on chat_rooms (match_id);
