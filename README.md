# VibeLens

VibeLens turns a photo into a production AI vibe result: playlist, quote, color filter, and shareable story card.

## Flutter Run

```powershell
flutter pub get
flutter run --dart-define=VIBELENS_API_BASE_URL=http://127.0.0.1:8000
```

Production builds must pass a real HTTPS backend URL:

```powershell
flutter build web --release --dart-define=VIBELENS_API_BASE_URL=https://api.your-domain.com
```

## Backend Run

```powershell
cd backend
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Fill `backend/.env` with OpenAI, `SUPABASE_DB_URL` for Supabase pgvector,
optional Supabase REST keys, Spotify client credentials, and `ADMIN_INGESTION_TOKEN`.

## Production Rules

- Image-only. No video upload, recording, preview, or microphone permission.
- Runtime `/analyze` never calls Spotify API.
- Spotify API is used only by admin ingestion.
- Flutter contains no OpenAI, Spotify secret, Supabase DB URL, or Supabase service role key.
- App opens Spotify URLs/search URLs only and never streams music.

## Checks

```powershell
flutter analyze
flutter test
python -m compileall backend\app
```
