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
  gender text default 'unknown',
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
  id uuid primary key default gen_random_uuid(),
  song_id text,
  track_id text,
  title text not null,
  artist text not null,
  normalized_key text unique,
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
  vibe_description text not null default '',
  embedding vector(768),
  embedding_model text,
  embedding_created_at timestamptz,
  source text default 'spotify_ingestion',
  ingested_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists songs_embedding_idx
  on songs using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

create index if not exists songs_genres_idx on songs using gin (genres);
create index if not exists songs_mood_tags_idx on songs using gin (mood_tags);
create index if not exists songs_scene_tags_idx on songs using gin (scene_tags);
create index if not exists songs_era_tags_idx on songs using gin (era_tags);
create index if not exists songs_language_idx on songs (language);
create unique index if not exists songs_normalized_key_idx on songs (normalized_key);

create or replace function match_songs(
  query_embedding vector(768),
  match_count int default 50
)
returns table (
  id uuid,
  song_id text,
  title text,
  artist text,
  spotify_url text,
  spotify_search_url text,
  album text,
  genres text[],
  mood_tags text[],
  scene_tags text[],
  era_tags text[],
  language text,
  energy_level numeric,
  valence_level numeric,
  age_affinity jsonb,
  popularity_tier text,
  vibe_description text,
  explicit boolean,
  similarity float
)
language sql stable
as $$
  select
    songs.id,
    songs.song_id,
    songs.title,
    songs.artist,
    songs.spotify_url,
    songs.spotify_search_url,
    songs.album,
    songs.genres,
    songs.mood_tags,
    songs.scene_tags,
    songs.era_tags,
    songs.language,
    songs.energy_level,
    songs.valence_level,
    songs.age_affinity,
    songs.popularity_tier,
    songs.vibe_description,
    songs.explicit,
    1 - (songs.embedding <=> query_embedding) as similarity
  from songs
  where songs.embedding is not null
  order by songs.embedding <=> query_embedding
  limit match_count;
$$;

create table if not exists embedding_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null,
  operation text not null,
  context text not null,
  model text not null,
  input_text_count int not null,
  estimated_tokens int null,
  estimated_cost numeric null,
  created_at timestamptz default now()
);
