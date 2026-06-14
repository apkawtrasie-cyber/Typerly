-- =============================================
-- AKTUALIZACJA PUNKTACJI — piłka ręczna ±3 bramki = 2 pkt
-- Opcja A: tolerancja ±3 bramki dla sport_type = 'handball'
-- =============================================

-- 1. Nowa wersja funkcji — przyjmuje opcjonalny sport_type
create or replace function calculate_match_points(
  p_home       integer,
  p_away       integer,
  r_home       integer,
  r_away       integer,
  p_sport_type text default null
) returns integer
language plpgsql
immutable
as $$
declare
  p_diff integer;
  r_diff integer;
begin
  -- 3 pkt: dokładny wynik — zawsze, dla każdego sportu
  if p_home = r_home and p_away = r_away then
    return 3;
  end if;

  -- 2 pkt: różne reguły w zależności od sportu
  if p_sport_type = 'handball' then
    -- Piłka ręczna: oba wyniki w granicach ±3 bramki
    if abs(p_home - r_home) <= 3 and abs(p_away - r_away) <= 3 then
      return 2;
    end if;
  else
    -- Piłka nożna / siatkówka: ta sama różnica bramek/setów
    p_diff := p_home - p_away;
    r_diff := r_home - r_away;
    if p_diff = r_diff then
      return 2;
    end if;
  end if;

  -- 1 pkt: poprawna tendencja (kto wygrał lub remis)
  if sign(p_home - p_away) = sign(r_home - r_away) then
    return 1;
  end if;

  return 0;
end;
$$;

-- 2. Aktualizacja score_predictions_for_match — przekazuje sport_type do funkcji
create or replace function score_predictions_for_match(
  p_match_id uuid,
  p_force    boolean default false
) returns integer
language plpgsql
security definer
as $$
declare
  v_home       integer;
  v_away       integer;
  v_sport_type text;
  v_count      integer;
begin
  select home_score, away_score, sport_type
    into v_home, v_away, v_sport_type
    from matches
   where id = p_match_id;

  -- Brak wyniku → nic nie rób
  if v_home is null or v_away is null then
    return 0;
  end if;

  update predictions
     set points_earned  = calculate_match_points(
                            predicted_home_score, predicted_away_score,
                            v_home, v_away,
                            v_sport_type
                          ),
         is_calculated  = true,
         updated_at     = now()
   where match_id       = p_match_id
     and (is_calculated = false or p_force = true);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- 3. Przelicz wstecz wszystkie już zapisane mecze piłki ręcznej
--    (żeby historyczne typy też dostały nowe punkty)
do $$
declare
  r record;
begin
  for r in
    select id from matches
     where sport_type = 'handball'
       and status = 'FT'
       and home_score is not null
       and away_score is not null
  loop
    perform score_predictions_for_match(r.id, true);
  end loop;
end;
$$;
