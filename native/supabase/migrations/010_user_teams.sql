-- Biblioteka drużyn użytkownika (wielorazowe, niezwiązane z konkretnym turniejem)
create table if not exists user_teams (
  id         uuid default gen_random_uuid() primary key,
  user_id    uuid references auth.users not null,
  name       text not null,
  logo_url   text,
  created_at timestamptz default now(),
  unique(user_id, name)
);
create index if not exists user_teams_user_idx on user_teams(user_id);

alter table user_teams enable row level security;

create policy "Odczyt własnych drużyn"
  on user_teams for select
  using (auth.uid() = user_id);

create policy "Zapis własnych drużyn"
  on user_teams for insert
  with check (auth.uid() = user_id);

create policy "Edycja własnych drużyn"
  on user_teams for update
  using (auth.uid() = user_id);

create policy "Usuwanie własnych drużyn"
  on user_teams for delete
  using (auth.uid() = user_id);
