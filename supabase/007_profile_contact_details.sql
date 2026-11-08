-- Add contact and location details to GiveEat user profiles.
-- Existing row-level security policies continue to restrict updates to each user's own profile.

alter table public.profiles
  add column if not exists phone text,
  add column if not exists city text,
  add column if not exists address text,
  add column if not exists description text;

grant update on table public.profiles to authenticated;
