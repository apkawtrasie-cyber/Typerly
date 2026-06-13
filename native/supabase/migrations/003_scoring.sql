-- =============================================
-- NALICZANIE PUNKTÓW — algorytm 3/2/1/0
-- =============================================

-- Upewnij się, że tabela predictions ma wymagane kolumny
alter table predictions
  add column if not exists points_earned  integer not null default 0,
  add column if not exists is_calculated  boolean not null default false,
  add column if not exists updated_at     timestamptz not null default now();

create index if not exists predictions_match_id_idx       on predictions(match_id);
create index if not exists predictions_user_id_idx        on predictions(user_id);
create index if not exists predictions_is_calculated_idx  on predictions(is_calculated);

-- =============================================
-- 1. Czysta funkcja punktacji (bez dostępu do DB)
-- Argumenty: typ gracza (p_home, p_away) i realny wynik (r_home, r_away)
-- =============================================
create or replace function calculate_match_points(
  p_home integer,
  p_away integer,
  r_home integer,
  r_away integer
) returns integer
language plpgsql
immutable
as $$
declare
  p_diff integer;
  r_diff integer;
begin
  -- 3 pkt: dokładny wynik
  if p_home = r_home and p_away = r_away then
    return 3;
  end if;

  p_diff := p_home - p_away;
  r_diff := r_home - r_away;

  -- 2 pkt: ta sama różnica bramek (pokrywa: poprawny zwycięzca + dokładna różnica,
  --         oraz poprawny remis przy innym dokładnym wyniku)
  if p_diff = r_diff then
    return 2;
  end if;

  -- 1 pkt: poprawna tendencja (wygrał ten sam lub obaj remisowali)
  if sign(p_diff) = sign(r_diff) then
    return 1;
  end if;

  return 0;
end;
$$;

-- =============================================
-- 2. Masowe przeliczenie typów dla jednego meczu
-- p_force = true → przelicz ponownie nawet już obliczone (korekta wyniku)
-- Zwraca liczbę zaktualizowanych wierszy.
-- =============================================
create or replace function score_predictions_for_match(
  p_match_id uuid,
  p_force    boolean default false
) returns integer
language plpgsql
security definer
as $$
declare
  v_home  integer;
  v_away  integer;
  v_count integer;
begin
  select home_score, away_score
    into v_home, v_away
    from matches
   where id = p_match_id;

  -- Brak wyniku → nic nie rób
  if v_home is null or v_away is null then
    return 0;
  end if;

  update predictions
     set points_earned  = calculate_match_points(
                            predicted_home_score, predicted_away_score,
                            v_home, v_away
                          ),
         is_calculated  = true,
         updated_at     = now()
   where match_id       = p_match_id
     and (is_calculated = false or p_force = true);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- =============================================
-- 3. Trigger na tabeli matches
-- Odpala przeliczenie gdy:
--   a) status zmienia się na 'FT' (mecz właśnie się zakończył)
--   b) status to już 'FT' ale zmienił się wynik (korekta danych)
-- =============================================
create or replace function trigger_score_predictions()
returns trigger
language plpgsql
security definer
as $$
declare
  v_force boolean;
begin
  if new.status = 'FT'
     and new.home_score is not null
     and new.away_score is not null
  then
    -- Korekta: wynik się zmienił mimo że status to wciąż FT
    v_force := (
      old.home_score is distinct from new.home_score
      or old.away_score is distinct from new.away_score
    );

    perform score_predictions_for_match(new.id::uuid, v_force);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_score_predictions on matches;

create trigger trg_score_predictions
  after update on matches
  for each row
  execute function trigger_score_predictions();

-- =============================================
-- RLS: właściciel widzi swoje typy; serwis (service_role) może wszystko
-- =============================================
alter table predictions enable row level security;

-- Odczyt: swoje typy lub typy w lidze, której jesteś członkiem
drop policy if exists "Odczyt własnych typów"           on predictions;
drop policy if exists "Odczyt typów w lidze"            on predictions;
drop policy if exists "Zapis własnych typów"            on predictions;
drop policy if exists "Modyfikacja własnych typów"      on predictions;

create policy "Odczyt własnych typów"
  on predictions for select
  using (auth.uid() = user_id);

create policy "Odczyt typów w lidze"
  on predictions for select
  using (
    exists (
      select 1 from league_members lm
      where lm.league_id = predictions.league_id
        and lm.user_id   = auth.uid()
    )
  );

create policy "Zapis własnych typów"
  on predictions for insert
  with check (auth.uid() = user_id);

create policy "Modyfikacja własnych typów"
  on predictions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
