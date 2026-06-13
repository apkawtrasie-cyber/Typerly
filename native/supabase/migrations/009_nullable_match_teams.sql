-- Mecze knockout mogą mieć TBD drużyny (NULL zanim znamy zwycięzcę)
alter table custom_matches
  alter column home_team_id drop not null,
  alter column away_team_id drop not null;
