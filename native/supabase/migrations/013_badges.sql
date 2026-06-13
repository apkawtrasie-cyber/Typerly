-- =============================================
-- SYSTEM ODZNAK (BADGES) — Typerly
-- =============================================

-- Tabela definicji odznak (katalog)
create table if not exists badge_definitions (
  id          text primary key,          -- np. 'exact_score', 'consolation'
  name        text not null,             -- wyświetlana nazwa
  description text not null,
  icon        text not null,             -- emoji lub nazwa pliku lottie
  rarity      text not null default 'common',  -- common / rare / epic / legendary
  created_at  timestamptz not null default now()
);

-- Odznaki użytkowników — każdy wiersz = przyznana odznaka
create table if not exists user_badges (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  badge_id     text not null references badge_definitions(id),
  awarded_at   timestamptz not null default now(),
  match_id     uuid references matches(id) on delete set null,
  unique(user_id, badge_id)   -- każda odznaka raz (możesz usunąć unique jeśli chcesz wielokrotne)
);

create index if not exists user_badges_user_id_idx on user_badges(user_id);

-- Kolumna sumaryczna w profiles dla szybkiego odczytu w leaderboard
alter table profiles
  add column if not exists badges_count integer not null default 0,
  add column if not exists trophies_count integer not null default 0;

-- ── RLS ──────────────────────────────────────────────────────────
alter table badge_definitions enable row level security;
alter table user_badges enable row level security;

-- Definicje — publiczny odczyt
drop policy if exists "Public badge definitions" on badge_definitions;
create policy "Public badge definitions"
  on badge_definitions for select using (true);

-- user_badges — każdy widzi swoje, zalogowani widzą wszystkich (do rankingu)
drop policy if exists "Odczyt własnych odznak" on user_badges;
drop policy if exists "Odczyt odznak innych"   on user_badges;
drop policy if exists "Przyznawanie odznak"     on user_badges;

create policy "Odczyt własnych odznak"
  on user_badges for select
  using (auth.uid() = user_id);

create policy "Odczyt odznak innych"
  on user_badges for select
  using (auth.role() = 'authenticated');

-- Wstawianie przez service_role (trigger/edge function) lub samego użytkownika
create policy "Przyznawanie odznak"
  on user_badges for insert
  with check (auth.uid() = user_id);

-- ── Katalog odznak (seed) ──────────────────────────────────────
insert into badge_definitions (id, name, description, icon, rarity) values
  ('exact_score',    'Snajper',         'Trafiłeś dokładny wynik meczu',              '🎯', 'rare'),
  ('goal_diff',      'Strateg',         'Trafiłeś różnicę bramek',                    '⚡', 'common'),
  ('tendency',       'Analityk',        'Trafiłeś tendencję meczu',                   '📊', 'common'),
  ('consolation',    'Tarcza',          'Nie trafiłeś, ale grasz dalej — to też ważne','🛡️', 'common'),
  ('first_tip',      'Debiutant',       'Złożyłeś pierwszy typ w Typerly',            '🌟', 'common'),
  ('streak_3',       'Passa x3',        'Trafiłeś 3 typy z rzędu',                    '🔥', 'rare'),
  ('streak_5',       'Gorąca passa',    'Trafiłeś 5 typów z rzędu',                   '💥', 'epic'),
  ('perfect_week',   'Tydzień doskonały','Wszystkie typy w tygodniu poprawne',         '👑', 'legendary'),
  ('total_10',       'Weteran',         'Zdobyłeś łącznie 10 punktów',                '🏅', 'rare'),
  ('total_50',       'Mistrz typowania', 'Zdobyłeś łącznie 50 punktów',               '🏆', 'epic')
on conflict (id) do nothing;

-- ── Trigger: przyznaj odznakę po zalogowaniu punktów ──────────
create or replace function award_badges_after_score()
returns trigger
language plpgsql
security definer
as $$
declare
  v_total_points integer;
  v_exact_count  integer;
begin
  -- Zlicz sumaryczne punkty gracza
  select coalesce(sum(points_earned), 0) into v_total_points
    from predictions
   where user_id = new.user_id and is_calculated = true;

  -- Odznaka: dokładny wynik
  if new.points_earned = 3 then
    insert into user_badges (user_id, badge_id, match_id)
      values (new.user_id, 'exact_score', new.match_id)
      on conflict do nothing;
  end if;

  -- Odznaka: różnica bramek
  if new.points_earned = 2 then
    insert into user_badges (user_id, badge_id, match_id)
      values (new.user_id, 'goal_diff', new.match_id)
      on conflict do nothing;
  end if;

  -- Odznaka: tendencja
  if new.points_earned = 1 then
    insert into user_badges (user_id, badge_id, match_id)
      values (new.user_id, 'tendency', new.match_id)
      on conflict do nothing;
  end if;

  -- Odznaka pocieszenia
  if new.points_earned = 0 then
    insert into user_badges (user_id, badge_id, match_id)
      values (new.user_id, 'consolation', new.match_id)
      on conflict do nothing;
  end if;

  -- Odznaka: 10 punktów łącznie
  if v_total_points >= 10 then
    insert into user_badges (user_id, badge_id)
      values (new.user_id, 'total_10')
      on conflict do nothing;
  end if;

  -- Odznaka: 50 punktów łącznie
  if v_total_points >= 50 then
    insert into user_badges (user_id, badge_id)
      values (new.user_id, 'total_50')
      on conflict do nothing;
  end if;

  -- Aktualizuj licznik w profiles
  update profiles
     set badges_count  = (select count(*) from user_badges where user_id = new.user_id),
         trophies_count = (select count(*) from user_badges ub
                           join badge_definitions bd on bd.id = ub.badge_id
                           where ub.user_id = new.user_id and bd.rarity in ('rare','epic','legendary'))
   where id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_award_badges on predictions;
create trigger trg_award_badges
  after update of points_earned on predictions
  for each row
  when (new.is_calculated = true)
  execute function award_badges_after_score();
