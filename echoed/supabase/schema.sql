-- =============================================================================
-- Echoed — Supabase Database Schema
-- Run this in your Supabase SQL editor or via `supabase db push`.
-- =============================================================================

-- Extensions
create extension if not exists "pgcrypto";

-- =============================================================================
-- TABLES
-- =============================================================================

-- Users (mirrors Supabase auth.users, stores app-level data)
create table if not exists public.users (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text unique,
  display_name    text,
  is_premium      boolean default false,
  premium_until   timestamptz,
  revenuecat_id   text,
  created_at      timestamptz default now()
);

-- Subscriptions (mirrored from RevenueCat webhooks)
create table if not exists public.subscriptions (
  user_id             uuid primary key references public.users(id) on delete cascade,
  plan                text check (plan in ('monthly', 'annual')),
  status              text check (status in ('active', 'trial', 'expired', 'cancelled')),
  current_period_end  timestamptz,
  updated_at          timestamptz default now()
);

-- Daily challenges (one seed per UTC day)
create table if not exists public.daily_challenges (
  challenge_date  date primary key,
  seed            bigint not null unique,
  generated_at    timestamptz default now()
);

-- Multiplayer sessions
create table if not exists public.game_sessions (
  id              uuid primary key default gen_random_uuid(),
  code            char(6) unique not null,
  host_user_id    uuid references public.users(id),
  seed            bigint not null,
  mode            text check (mode in ('solo', 'hard')) default 'solo',
  status          text check (status in ('waiting', 'active', 'complete')) default 'waiting',
  created_at      timestamptz default now(),
  started_at      timestamptz
);

-- Players in a multiplayer session
create table if not exists public.session_players (
  session_id    uuid references public.game_sessions(id) on delete cascade,
  user_id       uuid references public.users(id),
  guest_token   text,
  joined_at     timestamptz default now(),
  is_ready      boolean default false,
  constraint session_players_pkey primary key (session_id, coalesce(user_id::text, guest_token))
);

-- Game results (solo, daily, and multiplayer)
create table if not exists public.game_results (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references public.users(id),
  guest_token     text,
  session_id      uuid references public.game_sessions(id),
  seed            bigint not null,
  mode            text not null,
  is_daily        boolean default false,
  challenge_date  date,
  total_score     numeric(5, 2) not null,
  tone_scores     jsonb not null,
  submitted_at    timestamptz default now()
);

-- Seasonal tone packs (premium)
create table if not exists public.seasonal_packs (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  description   text,
  theme_tag     text,
  released_at   date,
  seeds         bigint[] not null,
  is_active     boolean default true
);

-- =============================================================================
-- INDEXES
-- =============================================================================

create index if not exists idx_game_results_user_id on public.game_results(user_id);
create index if not exists idx_game_results_challenge_date on public.game_results(challenge_date) where is_daily = true;
create index if not exists idx_game_results_session_id on public.game_results(session_id);
create index if not exists idx_game_sessions_code on public.game_sessions(code);

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Daily leaderboard view
create or replace view public.daily_leaderboard as
  select
    gr.challenge_date,
    coalesce(u.display_name, 'Guest') as display_name,
    gr.user_id,
    gr.total_score,
    gr.mode,
    gr.submitted_at,
    rank() over (partition by gr.challenge_date order by gr.total_score desc) as rank
  from public.game_results gr
  left join public.users u on u.id = gr.user_id
  where gr.is_daily = true;

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Player stats function
create or replace function public.get_player_stats(p_user_id uuid)
returns json
language plpgsql
security definer
as $$
declare
  v_games_played  int;
  v_avg_score     numeric;
  v_best_score    numeric;
  v_streak_days   int;
  v_history       json;
begin
  select
    count(*),
    avg(total_score),
    max(total_score)
  into v_games_played, v_avg_score, v_best_score
  from public.game_results
  where user_id = p_user_id;

  -- Score history: last 30 results
  select json_agg(h order by h.submitted_at desc)
  into v_history
  from (
    select total_score, submitted_at
    from public.game_results
    where user_id = p_user_id
    order by submitted_at desc
    limit 30
  ) h;

  -- Streak: consecutive days with at least 1 game
  with daily_plays as (
    select distinct date_trunc('day', submitted_at at time zone 'utc')::date as play_date
    from public.game_results
    where user_id = p_user_id
    order by play_date desc
  ),
  with_gaps as (
    select
      play_date,
      play_date - (row_number() over (order by play_date desc))::int as grp
    from daily_plays
  )
  select count(*) into v_streak_days
  from with_gaps
  where grp = (select grp from with_gaps order by play_date desc limit 1);

  return json_build_object(
    'games_played', coalesce(v_games_played, 0),
    'avg_score', round(coalesce(v_avg_score, 0), 2),
    'best_score', coalesce(v_best_score, 0),
    'streak_days', coalesce(v_streak_days, 0),
    'score_history', coalesce(v_history, '[]'::json)
  );
end;
$$;

-- Auto-create user profile on Supabase auth signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.users (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Trigger: create profile on auth.users insert
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

alter table public.users enable row level security;
alter table public.subscriptions enable row level security;
alter table public.game_results enable row level security;
alter table public.game_sessions enable row level security;
alter table public.session_players enable row level security;
alter table public.seasonal_packs enable row level security;

-- users: users can only read/update their own row
create policy "users: select own" on public.users
  for select using (auth.uid() = id);
create policy "users: update own" on public.users
  for update using (auth.uid() = id);

-- subscriptions: users can read their own
create policy "subscriptions: select own" on public.subscriptions
  for select using (auth.uid() = user_id);

-- game_results: users can insert and read their own; anyone can read daily results
create policy "game_results: insert own" on public.game_results
  for insert with check (auth.uid() = user_id or user_id is null);
create policy "game_results: select own" on public.game_results
  for select using (auth.uid() = user_id or is_daily = true);

-- game_sessions: anyone can read; only host can update
create policy "game_sessions: select all" on public.game_sessions
  for select using (true);
create policy "game_sessions: insert" on public.game_sessions
  for insert with check (auth.uid() = host_user_id or host_user_id is null);
create policy "game_sessions: update host" on public.game_sessions
  for update using (auth.uid() = host_user_id);

-- session_players: anyone can insert (guest join); read is public
create policy "session_players: insert" on public.session_players
  for insert with check (true);
create policy "session_players: select" on public.session_players
  for select using (true);

-- seasonal_packs: read if active (premium check is in Edge Function)
create policy "seasonal_packs: select active" on public.seasonal_packs
  for select using (is_active = true);

-- daily_challenges: public read
alter table public.daily_challenges enable row level security;
create policy "daily_challenges: select all" on public.daily_challenges
  for select using (true);
