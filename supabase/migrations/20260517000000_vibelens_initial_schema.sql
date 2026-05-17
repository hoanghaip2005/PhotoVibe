create extension if not exists vector with schema extensions;

create table if not exists profiles (
  id uuid primary key,
  email text,
  display_name text,
  avatar_url text,
  plan text default 'free',
  created_at timestamptz default now()
);

create table if not exists user_music_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  age_group text default 'unknown',
  preferred_genres text[] default '{}',
  preferred_languages text[] default '{}',
  music_era_preference text default 'mood_based',
  favorite_artists text[] default '{}',
  favorite_songs text[] default '{}',
  explicit_content_allowed boolean default false,
  discovery_level text default 'balanced',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists vibe_results (
  id uuid primary key,
  user_id uuid references profiles(id),
  vibe_name text not null,
  description text not null,
  mood_tags text[] default '{}',
  scene_tags text[] default '{}',
  confidence numeric,
  palette_hex text[] default '{}',
  quote_text text,
  quote_source text default 'VibeLens AI',
  quote_is_ai_generated boolean default true,
  filter_preset jsonb,
  playlist_query text,
  personalization jsonb,
  thumbnail_url text null,
  is_saved boolean default false,
  created_at timestamptz default now()
);

create table if not exists generated_playlists (
  id uuid primary key,
  user_id uuid references profiles(id),
  vibe_result_id uuid references vibe_results(id),
  name text not null,
  description text,
  mood_tags text[] default '{}',
  source text default 'vibelens',
  created_at timestamptz default now()
);

create table if not exists playlist_songs (
  id uuid primary key default gen_random_uuid(),
  playlist_id uuid references generated_playlists(id),
  song_id text null,
  title text not null,
  artist text not null,
  spotify_url text null,
  spotify_search_url text not null,
  match_percent integer,
  reason text,
  genres text[] default '{}',
  position integer,
  created_at timestamptz default now()
);

create table if not exists saved_filters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  name text not null,
  brightness numeric default 0,
  contrast numeric default 0,
  saturation numeric default 0,
  warmth numeric default 0,
  fade numeric default 0,
  grain numeric default 0,
  vignette numeric default 0,
  palette_hex text[] default '{}',
  created_at timestamptz default now()
);

create table if not exists ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references profiles(id),
  anonymous_id text null,
  date date,
  model text,
  check_count integer default 1,
  input_tokens integer,
  output_tokens integer,
  estimated_cost numeric,
  created_at timestamptz default now()
);

create table if not exists ingestion_jobs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid null,
  source text,
  playlist_ids text[] default '{}',
  status text,
  imported_count integer default 0,
  skipped_count integer default 0,
  failed_count integer default 0,
  error_message text null,
  started_at timestamptz,
  finished_at timestamptz null,
  created_at timestamptz default now()
);

create index if not exists idx_vibe_results_user_created
  on vibe_results(user_id, created_at desc);

create index if not exists idx_generated_playlists_user_created
  on generated_playlists(user_id, created_at desc);

create index if not exists idx_playlist_songs_playlist_position
  on playlist_songs(playlist_id, position);

create table if not exists songs (
  song_id text primary key,
  track_id text,
  title text not null,
  artist text not null,
  spotify_url text null,
  spotify_search_url text not null,
  album text null,
  artwork text null,
  duration_ms integer null,
  explicit boolean default false,
  genres text[] default '{}',
  mood_tags text[] default '{}',
  scene_tags text[] default '{}',
  era_tags text[] default '{}',
  language text default 'unknown',
  energy_level numeric default 0.5,
  valence_level numeric default 0.5,
  age_affinity jsonb default '{"teen": 0.5, "young_adult": 0.5, "adult": 0.5, "middle_age": 0.5, "senior": 0.5}'::jsonb,
  popularity_tier text default 'unknown',
  vibe_description text default '',
  embedding vector(1536),
  ingested_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_songs_embedding_hnsw
  on songs using hnsw (embedding vector_cosine_ops);

create index if not exists idx_songs_mood_tags
  on songs using gin (mood_tags);

create index if not exists idx_songs_scene_tags
  on songs using gin (scene_tags);
