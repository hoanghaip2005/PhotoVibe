create extension if not exists vector;

alter table songs add column if not exists id uuid default gen_random_uuid();
update songs set id = gen_random_uuid() where id is null;
alter table songs alter column id set not null;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'songs'::regclass
      and conname = 'songs_pkey'
  ) then
    alter table songs drop constraint songs_pkey;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'songs'::regclass
      and conname = 'songs_pkey'
  ) then
    alter table songs add constraint songs_pkey primary key (id);
  end if;
end $$;

alter table songs add column if not exists normalized_key text;

with keyed as (
  select
    id,
    coalesce(
      nullif(
        trim(both '-' from regexp_replace(lower(title || '-' || artist), '[^a-z0-9]+', '-', 'g')),
        ''
      ),
      'song'
    ) as base_key
  from songs
),
deduped as (
  select
    id,
    base_key,
    row_number() over (partition by base_key order by id) as duplicate_index
  from keyed
)
update songs
set normalized_key = case
  when deduped.duplicate_index = 1 then deduped.base_key
  else deduped.base_key || '-' || deduped.duplicate_index::text
end
from deduped
where songs.id = deduped.id
  and songs.normalized_key is null;

alter table songs alter column normalized_key set not null;

alter table songs add column if not exists embedding_model text;
alter table songs add column if not exists embedding_created_at timestamptz;
alter table songs add column if not exists source text default 'spotify_ingestion';

do $$
declare
  embedding_type text;
begin
  select format_type(atttypid, atttypmod)
  into embedding_type
  from pg_attribute
  where attrelid = 'songs'::regclass
    and attname = 'embedding'
    and not attisdropped;

  if embedding_type is not null and embedding_type not like '%vector(768)' then
    if not exists (
      select 1
      from pg_attribute
      where attrelid = 'songs'::regclass
        and attname = 'embedding_legacy_1536'
        and not attisdropped
    ) then
      alter table songs rename column embedding to embedding_legacy_1536;
    else
      alter table songs drop column embedding;
    end if;
  end if;

  if not exists (
    select 1
    from pg_attribute
    where attrelid = 'songs'::regclass
      and attname = 'embedding'
      and not attisdropped
  ) then
    alter table songs add column embedding vector(768);
  end if;
end $$;

drop index if exists idx_songs_embedding_hnsw;
drop index if exists idx_songs_mood_tags;
drop index if exists idx_songs_scene_tags;

create index if not exists songs_embedding_idx
on songs
using ivfflat (embedding vector_cosine_ops)
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
