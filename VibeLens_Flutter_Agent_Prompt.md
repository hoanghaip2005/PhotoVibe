# VibeLens — Prompt chỉnh app: Image-Only + Option B Spotify Admin Ingestion + Age/Preference Personalization

## 0. Mục tiêu

Dùng prompt này để đưa cho coding agent chỉnh sửa app VibeLens hiện tại.

Quyết định cuối:
- App chỉ hỗ trợ **chụp ảnh / upload ảnh**.
- Không hỗ trợ video.
- Dùng repo `https://github.com/datastax/vibe-check` làm **backend reference**.
- Chọn **Option B** làm hướng chính: dùng **Spotify API cho admin/offline ingestion** để nhập dữ liệu bài hát từ Spotify playlist vào database.
- Runtime user **không gọi Spotify API**.
- Runtime user chỉ:
  - gửi ảnh lên backend,
  - AI phân tích vibe,
  - backend search bài hát trong Astra DB,
  - trả playlist về Flutter,
  - user bấm “Mở trên Spotify”.

Bổ sung nghiệp vụ mới:
- Lúc tạo tài khoản/onboarding, app cần thu thập:
  - độ tuổi hoặc nhóm tuổi,
  - thể loại nhạc yêu thích,
  - nghệ sĩ/bài hát thích,
  - thập niên/era nhạc thích,
  - mức độ thích nhạc mới/trẻ/trending hay nhạc cũ/classic,
  - ngôn ngữ nhạc ưu tiên.
- Khi AI trả playlist, backend phải **phân tầng/rerank bài hát theo profile người dùng**, vì mỗi độ tuổi và gu nghe nhạc có thể phù hợp với playlist khác nhau.

---

## 1. Final product scope

### 1.1. App làm gì?

```text
User chụp ảnh hoặc upload ảnh
→ xem preview ảnh
→ nhập hint hoặc chọn mood nếu muốn
→ backend phân tích ảnh bằng AI
→ backend tạo vibe query
→ backend tìm bài hát trong Astra DB songs collection
→ backend rerank kết quả theo độ tuổi + gu nhạc của user
→ trả VibeResult về Flutter
→ Flutter hiển thị vibe, playlist, quote, filter, palette
→ user bấm “Mở trên Spotify”
→ mở Spotify app/web bằng track URL hoặc search URL
```

### 1.2. App không làm gì?

```text
Không upload video.
Không quay video.
Không phân tích video.
Không lấy frame video.
Không xin microphone permission.
Không phát nhạc trong app.
Không stream preview audio.
Không tạo playlist vào tài khoản Spotify ở MVP.
Không bắt user login Spotify ở MVP.
Không gọi Spotify API trong mỗi lượt user check vibe.
Không để OpenAI/Astra/Spotify secret trong Flutter.
```

---

## 2. Bỏ toàn bộ video khỏi app

Coding agent phải xóa toàn bộ video flow.

### 2.1. Xóa khỏi UI

Xóa:

```text
Upload Video
Video tab
Record Video
Video duration
3–15 seconds
MP4/MOV
Video preview
Video thumbnail
Trim video
```

Giữ:

```text
Chụp ảnh
Tải ảnh lên
Chọn ảnh từ thư viện
Xem trước ảnh
Phân tích vibe
```

### 2.2. Xóa khỏi dependencies

Nếu có trong `pubspec.yaml`, loại bỏ:

```yaml
video_player
chewie
ffmpeg_kit_flutter
video_thumbnail
```

Giữ các package ảnh:

```yaml
image_picker
permission_handler
share_plus
path_provider
cached_network_image
```

### 2.3. Xóa permission không cần

Không xin:

```text
microphone
record audio
video capture permission
```

Chỉ xin:

```text
camera
photos/gallery
storage/media nếu nền tảng cần
```

---

## 3. Kiến trúc production mặc định

### 3.1. Stack chọn mặc định

```text
Flutter app
FastAPI backend
OpenAI vision model
Astra DB vector collection cho songs
Supabase cho auth + app data
Spotify API chỉ cho admin ingestion
```

Lý do:
- `datastax/vibe-check` là Python demo, nên FastAPI phù hợp để tái sử dụng logic.
- Astra DB giữ vai trò vector search bài hát theo vibe.
- Supabase lưu user, profile, diary, playlist, filter, quota AI.
- Flutter không chứa secret.

---

## 4. Option B — Spotify API cho Admin Ingestion

### 4.1. Hiểu đúng Option B

Option B nghĩa là:

```text
Spotify API = công cụ nhập kho nhạc cho admin
Astra DB = database search nhạc chính
Flutter runtime = không gọi Spotify API
```

Flow:

```text
Admin nhập Spotify playlist IDs
→ backend gọi Spotify API lấy danh sách bài hát
→ lấy title, artist, track id, Spotify URL
→ LLM tạo vibe_description cho từng bài
→ tạo embedding/vector hoặc dùng Astra $vectorize
→ lưu vào Astra DB collection songs
```

Sau khi ingest xong:

```text
User check ảnh
→ backend search Astra DB
→ trả bài hát đã có Spotify URL/search URL
→ Flutter mở Spotify app/web khi user bấm
```

### 4.2. Endpoint admin

Cần tạo:

```text
POST /admin/ingest-spotify-playlist
```

Request:

```json
{
  "playlistIds": [
    "37i9dQZF1DX4WYpdgoIcn6"
  ],
  "limitPerPlaylist": 100,
  "regenerateVibeDescription": false
}
```

Response:

```json
{
  "imported": 87,
  "skippedDuplicates": 13,
  "failed": 0,
  "collection": "songs"
}
```

### 4.3. Backend xử lý ingestion

```text
1. Kiểm tra admin auth/token.
2. Lấy Spotify access token bằng Client Credentials hoặc admin OAuth nếu cần.
3. Gọi Spotify API để lấy playlist items.
4. Chuẩn hóa metadata:
   - title
   - artist
   - track_id
   - spotify_url
   - spotify_search_url
   - album optional
   - artwork optional nếu policy cho phép
   - duration_ms optional
   - explicit optional
5. Bỏ duplicate theo track_id hoặc title+artist.
6. Nếu bài chưa có vibe_description:
   - gọi LLM tạo vibe_description, mood_tags, scene_tags, age_affinity, era_tags.
7. Lưu document vào Astra DB.
8. Ghi log ingestion.
```

### 4.4. Không gọi Spotify API ở runtime

Endpoint `/analyze` không được gọi Spotify API.

Sai:

```text
/analyze
→ gọi Spotify search/recommendations
→ trả bài hát realtime
```

Đúng:

```text
/analyze
→ gọi OpenAI phân tích ảnh
→ search Astra DB songs
→ rerank theo user profile
→ trả playlist
```

---

## 5. Song document trong Astra DB

Mỗi bài hát phải có vibe để search.

Document mẫu:

```json
{
  "song_id": "spotify:track:xxx",
  "title": "Song title",
  "artist": "Artist name",
  "spotify_url": "https://open.spotify.com/track/xxx",
  "spotify_search_url": "https://open.spotify.com/search/Song%20title%20Artist",
  "album": "Album name",
  "genres": ["indie", "acoustic"],
  "mood_tags": ["calm", "nostalgic", "healing"],
  "scene_tags": ["forest", "sunset", "rain"],
  "era_tags": ["2010s", "modern_indie"],
  "language": "en",
  "energy_level": 0.35,
  "valence_level": 0.55,
  "age_affinity": {
    "teen": 0.55,
    "young_adult": 0.85,
    "adult": 0.75,
    "middle_age": 0.45,
    "senior": 0.25
  },
  "popularity_tier": "mainstream",
  "vibe_description": "A soft indie acoustic track for forest walks, golden sunset light, nostalgia, and calm reflection.",
  "$vectorize": "A soft indie acoustic track for forest walks, golden sunset light, nostalgia, and calm reflection."
}
```

### 5.1. Vì sao cần `age_affinity`?

Vì nhóm đã chốt nghiệp vụ:

```text
Người già có thể không hợp nhạc trẻ.
Người trẻ có thể thích trend/modern hơn.
AI phải phân tầng bài hát lúc trả result.
```

Không nên chỉ dựa vào AI đoán theo ảnh. Cần dùng profile user để rerank.

---

## 6. LLM tạo vibe_description cho bài hát

Trong ingestion, gọi LLM cho từng bài hoặc batch nhiều bài.

Prompt mẫu:

```text
You are VibeLens Music Tagger.

Create metadata for a song so it can be searched by visual vibe.

Input:
- title
- artist
- album
- genres if available
- optional playlist context

Return JSON only:
{
  "vibe_description": "...",
  "mood_tags": ["..."],
  "scene_tags": ["..."],
  "era_tags": ["..."],
  "language": "vi|en|ko|ja|other|unknown",
  "energy_level": 0.0,
  "valence_level": 0.0,
  "age_affinity": {
    "teen": 0.0,
    "young_adult": 0.0,
    "adult": 0.0,
    "middle_age": 0.0,
    "senior": 0.0
  },
  "popularity_tier": "classic|mainstream|underground|trending|unknown"
}

Rules:
- Do not invent copyrighted lyrics.
- Do not claim exact user preference.
- Use broad age suitability, not stereotypes.
- age_affinity means likely listening fit, not a hard rule.
- If unsure, keep scores moderate.
```

---

## 7. User onboarding/account setup

### 7.1. Lúc tạo account cần hỏi gì?

Sau khi user đăng ký hoặc mở app lần đầu, thêm onboarding step:

#### Step 1 — Nhóm tuổi

Không nên hỏi ngày sinh bắt buộc nếu không cần. Hỏi nhóm tuổi là đủ.

```text
Bạn thuộc nhóm tuổi nào?
- Dưới 18
- 18–24
- 25–34
- 35–44
- 45–54
- 55+
- Không muốn trả lời
```

Map nội bộ:

```text
under_18 → teen
18_24 → young_adult
25_34 → young_adult/adult
35_44 → adult
45_54 → middle_age
55_plus → senior
unknown → neutral
```

#### Step 2 — Thể loại nhạc yêu thích

Multi-select:

```text
Pop
Indie
Lo-fi
Acoustic
EDM
Hip-hop/Rap
R&B
Rock
Ballad
V-Pop
K-Pop
Classical
Jazz
Bolero
Nhạc Trịnh / oldies
Không chắc
```

#### Step 3 — Gu nhạc mới/cũ

```text
Bạn thích kiểu nhạc nào hơn?
- Nhạc mới / trending
- Nhạc hiện đại nhưng không quá trend
- Cân bằng mới và cũ
- Nhạc cũ / classic
- Tùy mood
```

Internal:

```text
music_era_preference:
- trending
- modern
- balanced
- classic
- mood_based
```

#### Step 4 — Ngôn ngữ nhạc

```text
Bạn thường nghe nhạc ngôn ngữ nào?
- Tiếng Việt
- Tiếng Anh
- Hàn
- Nhật
- Không quan trọng
```

#### Step 5 — Nghệ sĩ hoặc bài hát yêu thích

Optional text input:

```text
Nhập vài nghệ sĩ/bài hát bạn thích...
```

Dùng để gợi ý genre/era/taste, không bắt buộc.

### 7.2. Không hỏi quá nhiều

Nếu muốn nhanh, cho phép:

```text
Bỏ qua
Thiết lập sau
```

Nếu user skip, backend dùng neutral profile.

---

## 8. User preference data model

### 8.1. Supabase table `user_music_preferences`

```sql
id uuid primary key
user_id uuid references profiles(id)
age_group text default 'unknown'
preferred_genres text[]
preferred_languages text[]
music_era_preference text default 'mood_based'
favorite_artists text[]
favorite_songs text[]
explicit_content_allowed boolean default false
discovery_level text default 'balanced'
created_at timestamptz
updated_at timestamptz
```

### 8.2. Enum gợi ý

```text
age_group:
- teen
- young_adult
- adult
- middle_age
- senior
- unknown

music_era_preference:
- trending
- modern
- balanced
- classic
- mood_based

discovery_level:
- familiar
- balanced
- adventurous
```

---

## 9. Playlist personalization/reranking

### 9.1. Không chỉ search vector là xong

Search pipeline phải có 2 tầng:

```text
Tầng 1: vector search theo vibe ảnh
Tầng 2: rerank theo user profile
```

Flow:

```text
AI phân tích ảnh → playlistQuery
Astra vector search lấy top 30–50 songs
Backend rerank theo:
- similarity score
- mood match
- preferred genres
- age group / age_affinity
- music era preference
- language preference
- explicit content
- diversity
→ chọn top 5–10 bài
```

### 9.2. Công thức score gợi ý

```text
final_score =
  0.45 * vector_similarity
+ 0.20 * mood_match
+ 0.15 * genre_preference_match
+ 0.10 * age_affinity_match
+ 0.05 * era_preference_match
+ 0.05 * language_match
- penalties
```

Penalties:

```text
explicit_content penalty nếu user không cho phép
duplicate artist penalty
too_many_same_genre penalty
low_confidence_metadata penalty
```

### 9.3. Giải thích reason cho từng bài

Mỗi song trả về cần có reason:

```json
{
  "title": "Song title",
  "artist": "Artist",
  "matchPercent": 91,
  "reason": "Hợp với vibe rừng yên tĩnh, gu indie/acoustic và sở thích nghe nhạc hiện đại của bạn.",
  "spotifyUrl": "https://open.spotify.com/track/xxx"
}
```

Nếu không có profile:

```text
Hợp với vibe ảnh và mood chill/healing.
```

### 9.4. Không stereotype theo tuổi

Không hard-code kiểu:

```text
55+ thì chỉ nghe nhạc cũ
teen thì chỉ nghe nhạc trend
```

Đúng hơn:

```text
age_group chỉ là signal mềm.
preferred_genres và favorite artists quan trọng hơn age_group.
user có thể chỉnh profile bất kỳ lúc nào.
```

---

## 10. Runtime `/analyze` API contract

Request multipart:

```text
image: file
hint: string optional
moodHints: string[] optional
analysisMode: auto | music_first | quote_first | filter_first | deep_mood
userId: string optional
anonymousId: string optional
saveResult: boolean default false
```

Backend steps:

```text
1. Validate image.
2. Compress/resize image nếu cần.
3. Load user_music_preferences nếu có userId.
4. Gọi OpenAI vision model phân tích ảnh.
5. Parse structured Vibe JSON.
6. Search Astra DB songs bằng playlistQuery/vibe description.
7. Lấy top 30–50 candidates.
8. Rerank candidates theo user preference.
9. Build playlist top 5–10 bài.
10. Generate reasons.
11. Log ai_usage.
12. Save result nếu requested.
13. Return VibeResult JSON.
```

Response:

```json
{
  "id": "result_123",
  "vibeName": "Forest Healing",
  "description": "Khoảnh khắc này có cảm giác xanh, yên tĩnh và chữa lành.",
  "moodTags": ["chill", "healing", "fresh", "calm"],
  "sceneTags": ["forest", "green", "natural light"],
  "confidence": 0.87,
  "paletteHex": ["#355E3B", "#8FBC8F", "#E8DCC4"],
  "personalization": {
    "ageGroupUsed": "young_adult",
    "genrePreferencesUsed": ["indie", "acoustic"],
    "eraPreferenceUsed": "modern"
  },
  "quote": {
    "text": "Có những ngày chỉ cần một khoảng xanh là lòng dịu lại.",
    "source": "VibeLens AI",
    "isAiGenerated": true
  },
  "filterPreset": {
    "name": "Forest Glow",
    "brightness": 0.06,
    "contrast": 0.08,
    "saturation": 0.16,
    "warmth": -0.04,
    "fade": 0.08,
    "grain": 0.04,
    "vignette": 0.1
  },
  "playlist": {
    "id": "playlist_123",
    "name": "Forest Healing Mix",
    "description": "Những bài nhạc nhẹ, xanh và thư giãn cho vibe thiên nhiên.",
    "songs": [
      {
        "title": "Song title",
        "artist": "Artist",
        "matchPercent": 91,
        "reason": "Hợp với vibe rừng yên tĩnh, gu indie/acoustic và sở thích nghe nhạc hiện đại của bạn.",
        "genres": ["indie", "acoustic"],
        "spotifyUrl": "https://open.spotify.com/track/xxx",
        "spotifySearchUrl": "https://open.spotify.com/search/Song%20Artist"
      }
    ]
  }
}
```

---

## 11. AI prompt cho phân tích ảnh

```text
You are VibeLens AI, a visual mood and music recommendation assistant.

Analyze the uploaded image as a moment, not as a diagnosis of the user.
Return Vietnamese JSON only.

Your task:
1. Describe the overall vibe of the image.
2. Identify mood tags and scene tags.
3. Create a playlistQuery that can be used to search a vector database of songs.
4. Generate one short AI quote in Vietnamese.
5. Generate one color filter preset.
6. Extract or infer a color palette.
7. Return confidence from 0 to 1.

User profile may include:
- age_group
- preferred_genres
- preferred_languages
- music_era_preference
- favorite_artists
- favorite_songs

Rules:
- Do not stereotype by age.
- Use age and preferences only as soft personalization signals.
- Do not diagnose mental health.
- Do not infer sensitive traits.
- Do not claim certainty about the user's emotion.
- Use "khoảnh khắc này" instead of "bạn".
- Quote source must be "VibeLens AI".
- Output JSON only.
```

Expected JSON:

```json
{
  "vibeName": "string",
  "description": "string",
  "moodTags": ["string"],
  "sceneTags": ["string"],
  "playlistQuery": "string",
  "quote": {
    "text": "string",
    "source": "VibeLens AI",
    "isAiGenerated": true
  },
  "filterPreset": {
    "name": "string",
    "brightness": 0.0,
    "contrast": 0.0,
    "saturation": 0.0,
    "warmth": 0.0,
    "fade": 0.0,
    "grain": 0.0,
    "vignette": 0.0
  },
  "paletteHex": ["#000000"],
  "confidence": 0.0
}
```

---

## 12. Flutter UI changes

### 12.1. Auth/onboarding

Add account setup flow:

```text
Tạo hồ sơ nghe nhạc
→ hỏi nhóm tuổi
→ hỏi thể loại thích
→ hỏi gu nhạc mới/cũ
→ hỏi ngôn ngữ nhạc
→ hỏi nghệ sĩ/bài hát thích optional
→ lưu vào Supabase
```

Vietnamese copy:

```text
Để VibeLens chọn nhạc hợp gu hơn
Bạn thuộc nhóm tuổi nào?
Bạn thích nghe thể loại nào?
Bạn thích nhạc mới, nhạc cũ hay tùy mood?
Bạn thường nghe nhạc ngôn ngữ nào?
Có nghệ sĩ hoặc bài hát nào bạn rất thích không?
```

### 12.2. Profile/settings

Add editable section:

```text
Gu nghe nhạc
- Nhóm tuổi
- Thể loại yêu thích
- Ngôn ngữ nhạc
- Gu nhạc mới/cũ
- Nghệ sĩ yêu thích
- Mức khám phá nhạc mới
```

### 12.3. Result screen

In playlist card, show personalization note:

```text
Đã cá nhân hóa theo vibe ảnh và gu nghe nhạc của bạn.
```

If no profile:

```text
Playlist dựa trên vibe ảnh. Bạn có thể thêm gu nghe nhạc để kết quả hợp hơn.
```

Each song tile should show:
- title
- artist
- match %
- reason
- “Mở trên Spotify”

---

## 13. Supabase database tables

### 13.1. `profiles`

```sql
id uuid primary key
email text
display_name text
avatar_url text
plan text default 'free'
created_at timestamptz
```

### 13.2. `user_music_preferences`

```sql
id uuid primary key
user_id uuid references profiles(id)
age_group text default 'unknown'
preferred_genres text[]
preferred_languages text[]
music_era_preference text default 'mood_based'
favorite_artists text[]
favorite_songs text[]
explicit_content_allowed boolean default false
discovery_level text default 'balanced'
created_at timestamptz
updated_at timestamptz
```

### 13.3. `vibe_results`

```sql
id uuid primary key
user_id uuid references profiles(id)
vibe_name text
description text
mood_tags text[]
scene_tags text[]
confidence numeric
palette_hex text[]
quote_text text
quote_source text
quote_is_ai_generated boolean default true
filter_preset jsonb
playlist_query text
personalization jsonb
thumbnail_url text null
is_saved boolean default false
created_at timestamptz
```

### 13.4. `generated_playlists`

```sql
id uuid primary key
user_id uuid references profiles(id)
vibe_result_id uuid references vibe_results(id)
name text
description text
mood_tags text[]
source text default 'vibelens'
created_at timestamptz
```

### 13.5. `playlist_songs`

```sql
id uuid primary key
playlist_id uuid references generated_playlists(id)
song_id text null
title text
artist text
spotify_url text null
spotify_search_url text
match_percent integer
reason text
genres text[]
position integer
created_at timestamptz
```

### 13.6. `saved_filters`

```sql
id uuid primary key
user_id uuid references profiles(id)
name text
brightness numeric
contrast numeric
saturation numeric
warmth numeric
fade numeric
grain numeric
vignette numeric
palette_hex text[]
created_at timestamptz
```

### 13.7. `ai_usage`

```sql
id uuid primary key
user_id uuid null
anonymous_id text null
date date
model text
check_count integer default 1
input_tokens integer
output_tokens integer
estimated_cost numeric
created_at timestamptz
```

### 13.8. `ingestion_jobs`

```sql
id uuid primary key
admin_user_id uuid null
source text
playlist_ids text[]
status text
imported_count integer default 0
skipped_count integer default 0
failed_count integer default 0
error_message text null
started_at timestamptz
finished_at timestamptz null
created_at timestamptz
```

---

## 14. Backend environment variables

```env
OPENAI_API_KEY=
OPENAI_VISION_MODEL=gpt-5.4-mini
OPENAI_INGESTION_MODEL=gpt-5.4-mini
OPENAI_EMBEDDING_MODEL=

ASTRA_DB_API_ENDPOINT=
ASTRA_DB_APPLICATION_TOKEN=
ASTRA_DB_KEYSPACE=
ASTRA_DB_COLLECTION=songs

SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_ANON_KEY=

SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
SPOTIFY_REDIRECT_URI=

ADMIN_INGESTION_TOKEN=

APP_ENV=development
```

---

## 15. Spotify policy/runtime rules

Implementation rules:

```text
Spotify API is allowed only in admin ingestion.
Runtime /analyze must not call Spotify API.
Flutter must not contain Spotify Client Secret.
Flutter must not require Spotify login in MVP.
App must not play music.
App must not stream previews.
App must not download audio.
App must only open Spotify URL/search URL.
```

Need retry/backoff:

```text
If Spotify returns 429:
- read Retry-After header
- wait
- retry
- log ingestion job status
```

---

## 16. Acceptance criteria

1. App không còn video UI/logic/dependency.
2. App chỉ có chụp ảnh/upload ảnh.
3. Có onboarding/account setup để thu thập age group + music preferences.
4. User có thể chỉnh gu nhạc trong Profile.
5. Backend có endpoint `/admin/ingest-spotify-playlist`.
6. Spotify API chỉ dùng ở admin ingestion.
7. `/analyze` không gọi Spotify API.
8. Astra DB `songs` có `vibe_description`, `mood_tags`, `scene_tags`, `age_affinity`, `era_tags`.
9. `/analyze` search Astra top candidates rồi rerank theo user profile.
10. Result playlist có reason cá nhân hóa.
11. App chỉ mở Spotify app/web bằng `spotifyUrl` hoặc `spotifySearchUrl`.
12. Không phát nhạc trong app.
13. Flutter không chứa AI/Spotify/Astra secrets.
14. Supabase lưu user profile, preferences, vibe results, playlists, filters, AI usage.
15. Privacy consent xuất hiện trước khi gửi ảnh lên AI.
16. App copy tiếng Việt-first.

---

## 17. Main prompt for coding agent

Copy phần dưới đây cho agent:

```text
You are a Senior Flutter + FastAPI product engineer. Edit the existing VibeLens app according to the final product decision.

Final decision:
VibeLens is image-only. Remove all video upload, video recording, video preview, video duration, video frame extraction, video permissions, video dependencies, and video copy.

Spotify strategy:
Use Option B. Spotify API is used only for admin/offline ingestion, not for normal user runtime.
Admin can submit Spotify playlist IDs. Backend fetches tracks from Spotify, extracts title/artist/track_id/Spotify URL, generates vibe_description and metadata with LLM, and stores songs into Astra DB.
Runtime user vibe checks must not call Spotify API. Runtime only searches Astra DB and returns songs with Spotify URLs/search URLs.
The app must not play music in-app. It only opens Spotify app/web.

Reference repo:
Use https://github.com/datastax/vibe-check as a backend reference only.
Keep the concept:
image + optional text hint → multimodal LLM vibe analysis → vector search songs → return matching songs.
Keep the ingestion idea:
Spotify playlist/source → song metadata → LLM creates vibe_description → store in Astra DB.
Do not port Streamlit UI. Convert relevant logic to FastAPI.

New personalization requirement:
During account setup/onboarding, collect music preference data:
- age group
- preferred genres
- preferred languages
- music era preference
- favorite artists/songs optional
- explicit content preference
- discovery level

Reason:
Different users may prefer different music even for the same visual vibe. Older users may not prefer very young/trending songs by default, and younger users may prefer modern/trending songs. However, age must be a soft signal only. Do not stereotype. User's selected genres and favorite artists should be stronger signals than age.

Backend playlist logic:
1. Analyze image with OpenAI vision model.
2. Generate playlistQuery.
3. Search Astra DB songs using vector similarity.
4. Retrieve top 30–50 candidates.
5. Rerank candidates using:
   - vector similarity
   - mood match
   - preferred genres
   - age_affinity
   - music era preference
   - preferred languages
   - explicit content setting
   - diversity penalties
6. Return top 5–10 songs.
7. Include a reason for each song explaining why it matches the image vibe and user preferences.

Default stack:
- Flutter app
- FastAPI backend
- OpenAI as AI provider
- Default model: gpt-5.4-mini
- Optional cheaper test model: gpt-5.4-nano
- Astra DB for songs vector collection
- Supabase for auth, user profile, preferences, diary, saved playlists, saved filters, AI usage
- Spotify API only for admin ingestion

Required backend endpoints:
- POST /analyze
- GET /results
- GET /results/{id}
- POST /results/{id}/save
- GET /playlists
- GET /playlists/{id}
- GET /filters
- POST /filters
- POST /admin/ingest-spotify-playlist
- POST /admin/ingest-songs-csv

Required Supabase tables:
- profiles
- user_music_preferences
- vibe_results
- generated_playlists
- playlist_songs
- saved_filters
- ai_usage
- ingestion_jobs

Astra song document must include:
- song_id
- title
- artist
- spotify_url
- spotify_search_url
- album optional
- genres
- mood_tags
- scene_tags
- era_tags
- language
- energy_level
- valence_level
- age_affinity
- popularity_tier
- vibe_description
- vector or $vectorize

Flutter screens:
- Splash
- Onboarding
- Account/Music Preference Setup
- Home
- Capture Image
- Preview Image
- Loading
- Result
- Playlist Library
- Playlist Detail
- Filter Editor
- Vibe Diary
- Profile/Settings

UI copy must be Vietnamese-first.
Use:
- Chụp ảnh
- Tải ảnh lên
- Phân tích vibe
- Mở trên Spotify
- Gu nghe nhạc
- Nhóm tuổi
- Thể loại yêu thích
- Gu nhạc mới/cũ
- Đã cá nhân hóa theo vibe ảnh và gu nghe nhạc của bạn

Privacy:
Before analysis, show consent:
“VibeLens sẽ gửi ảnh này đến máy chủ để AI phân tích vibe, màu sắc và bối cảnh. Ảnh gốc không được lưu mặc định sau khi phân tích. Chúng tôi chỉ lưu kết quả như vibe, playlist, quote và filter nếu bạn chọn lưu vào diary.”

Security:
Flutter must not contain OpenAI, Spotify Client Secret, Astra token, or Supabase service role key.
Secrets must stay in backend environment variables.

Acceptance criteria:
- No video feature remains.
- Spotify API exists only in admin ingestion.
- Runtime /analyze does not call Spotify API.
- Song DB contains vibe metadata and age_affinity.
- Playlist results are reranked by user profile.
- Result screen shows personalized reasons.
- App opens Spotify via URL/search URL only.
- AI usage/quota is logged.
```
