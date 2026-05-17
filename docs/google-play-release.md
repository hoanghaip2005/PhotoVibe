# Google Play Release Setup

GitHub Actions builds the Android App Bundle on every push and pull request to
`main`. Upload to Google Play runs only when you manually start the
`Android Release` workflow.

## Required GitHub Secrets

Add these in GitHub: `Settings` -> `Secrets and variables` -> `Actions`.

- `ANDROID_KEYSTORE_BASE64`: base64 content of the upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: key alias, for example `upload`.
- `ANDROID_KEY_PASSWORD`: key password.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: full JSON content of the Google Play
  service account key.

Optional repository variable:

- `VIBELENS_API_BASE_URL`: production API URL used by Flutter
  `--dart-define`. If missing, CI uses `https://api.vibelens.app`.

## Create an Upload Keystore

Run locally, then keep the generated file private:

```powershell
keytool -genkey -v -keystore android\app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` locally if you want to build signed releases on
this machine:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Encode the keystore for GitHub:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks")) | Set-Clipboard
```

## Google Play Service Account

In Google Play Console, create or connect a Google Cloud service account, grant
it release access for the app, then create a JSON key. Paste the entire JSON
file content into `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

The workflow publishes to the selected track, starting with `internal` by
default.
