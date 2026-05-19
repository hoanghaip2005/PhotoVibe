# VibeLens Play Console Setup

Use this checklist to finish Play Console setup before closed testing.

## App Content

### Privacy Policy

Status: required before review.

GitHub Pages URL:

`https://hoanghaip2005.github.io/PhotoVibe/privacy-policy.html`

Data deletion URL:

`https://hoanghaip2005.github.io/PhotoVibe/account-deletion.html`

VibeLens needs a public privacy policy URL because the app uses camera/gallery,
email/password auth, AI analysis, and in-app purchases. The policy must mention:

- App name: VibeLens.
- Developer or company name exactly as shown on the store listing.
- Data collected: email, display name, user ID, uploaded photos for analysis,
  vibe results, music preferences, saved playlists/filters, purchase status.
- Service providers: Supabase, OpenAI or configured AI provider, Google Play
  Billing.
- Data use: account management, AI analysis, personalization, purchases,
  support, abuse prevention.
- Data deletion: how users can delete their account and associated data.

### App Access

Recommended answer:

- Choose: Some or all functionality is restricted.
- Instructions for reviewer:
  `Open VibeLens, choose local profile if you want to test without an account, or use the supplied reviewer account. The main photo vibe check flow is available from the local profile.`

If Play Console requires credentials, create a Supabase test account and enter:

- Email: `reviewer@your-domain.example`
- Password: generate a temporary password and store it outside the repo.

### Ads

Recommended answer: No, the app does not contain ads.

### Content Rating

Recommended category: Lifestyle.

Suggested answers:

- Violence: No.
- Sexual content: No.
- Profanity: No.
- Controlled substances: No.
- User-generated content: Users upload photos only for personal AI analysis;
  there is no public feed or user-to-user sharing inside the app.
- Purchases: Yes, digital subscriptions/credit packs.

### Target Audience

Recommended answer: 18 and over.

Reason: VibeLens is not designed for children and uses AI photo analysis, account
auth, and paid digital products.

### Data Safety

Recommended disclosure:

- Data collected:
  - Personal info: email address, optional display name.
  - Photos and videos: photos uploaded for AI vibe analysis.
  - App activity: vibe results, saved playlists, saved filters, preferences.
  - App info and performance: only if you later add crash/analytics tooling.
  - Purchases: in-app purchase status/entitlements.
- Data shared with service providers:
  - Supabase for authentication/database.
  - AI provider for image analysis.
  - Google Play Billing for purchases.
- Data encrypted in transit: Yes.
- Users can request deletion: Yes, but only mark this complete after the app
  has an in-app deletion path and a public deletion request URL.

### Government Apps

Recommended answer: No.

### Financial Features

Recommended answer: No. In-app purchases are digital content access, not a
financial product.

### Health

Recommended answer: No. VibeLens does not provide health, medical, or wellness
advice.

## Store Presence

### Category and Contact Details

- App category: Lifestyle.
- Tags: Photo editor, Music, Lifestyle, AI.
- Contact email: use the Play developer support email.
- Website: optional, but recommended if you have a landing page.

### Main Store Listing

Short description:

`Biến ảnh thành vibe, playlist, quote và story card bằng AI.`

Long description:

`VibeLens biến một khoảnh khắc thành một vibe hoàn chỉnh: AI phân tích ảnh, gợi ý mood, playlist, quote, filter và story card để chia sẻ. Bạn có thể dùng hồ sơ local để thử nhanh hoặc đăng nhập để lưu kết quả theo tài khoản. Ứng dụng tập trung vào ảnh, cảm xúc, gu nhạc và trải nghiệm cá nhân hóa.`

Feature bullets:

- Analyze a photo into a vibe result.
- Get personalized playlist suggestions.
- Save vibe results, filters, and story cards.
- Use local mode or Supabase email/password account.
- Optional Pro plans and credit packs through Google Play Billing.

## Closed Testing

1. Go to Testing > Closed testing.
2. Select Manage track.
3. Add testers on the Testers tab.
4. Use an email list or Google Group.
5. Create a new release or use the uploaded AAB version code `5`.
6. Set release status to draft first, review all warnings, then roll out.
7. Copy the opt-in link and send it to testers.

For new personal developer accounts created after November 13, 2023, Google
requires at least 12 testers opted in for 14 consecutive days before production
access.
