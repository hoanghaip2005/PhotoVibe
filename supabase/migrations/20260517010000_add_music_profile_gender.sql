alter table if exists public.user_music_preferences
  add column if not exists gender text default 'unknown';
