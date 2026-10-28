-- Leverage database setup for Supabase.
-- Run this whole file in Supabase → SQL Editor to (re)create everything the app needs.
-- Safe to run more than once.

-- 1. Each person's saved data: one row per section of the app (history, workouts, body, nutrition, settings...).
create table if not exists public.user_data (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  key text not null,
  value text,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.user_data enable row level security;
drop policy if exists "Users manage their own data" on public.user_data;
create policy "Users manage their own data" on public.user_data
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. Community foods: one row per person holding the foods they shared.
--    Anyone can read them; each signed-in person can only add, change or remove their own row.
create table if not exists public.community_foods (
  id text primary key,
  user_id uuid default auth.uid() references auth.users on delete cascade,
  foods text not null default '[]',
  updated_at timestamptz not null default now()
);
alter table public.community_foods enable row level security;
drop policy if exists "Anyone can read community foods" on public.community_foods;
create policy "Anyone can read community foods" on public.community_foods
  for select to anon, authenticated using (true);
drop policy if exists "People add their own foods" on public.community_foods;
create policy "People add their own foods" on public.community_foods
  for insert to authenticated with check (user_id = auth.uid() and id = auth.uid()::text);
drop policy if exists "People change their own foods" on public.community_foods;
create policy "People change their own foods" on public.community_foods
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and id = auth.uid()::text);
drop policy if exists "People remove their own foods" on public.community_foods;
create policy "People remove their own foods" on public.community_foods
  for delete to authenticated using (user_id = auth.uid());

-- Also set in the Supabase dashboard (not SQL):
--   Authentication → URL Configuration → Site URL and Redirect URLs: https://jgsell7.github.io/Leverage/
--   Authentication → Sign In / Providers → Email → Confirm email: off (until a custom email service is connected)
