-- Levered database setup for Supabase.
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

-- 3. Feedback from the in-app Feedback button.
--    Anyone can send it (signed in or not); nobody can read it through the app. Read it in Table Editor → feedback.
create table if not exists public.feedback (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users on delete set null,
  email text,
  kind text not null default 'other',
  message text not null check (char_length(message) between 1 and 4000),
  screen text,
  device text,
  app_version text
);
alter table public.feedback enable row level security;
drop policy if exists "Anyone can send feedback" on public.feedback;
create policy "Anyone can send feedback" on public.feedback
  for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());

-- 4. Reports about community foods (the Report button). Anyone can send one; only you read them, in Table Editor → food_reports.
create table if not exists public.food_reports (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users on delete set null,
  food_owner text not null,
  food_id text not null,
  food_name text,
  reason text not null,
  note text check (note is null or char_length(note) <= 1000)
);
alter table public.food_reports enable row level security;
drop policy if exists "Anyone can report a food" on public.food_reports;
create policy "Anyone can report a food" on public.food_reports
  for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());

-- 5. In-app account deletion. Deleting the account also removes its synced data and shared foods
--    (their tables cascade); feedback and reports it sent are kept without the link to the account.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
