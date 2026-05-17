import 'dart:typed_data';

import '../models/analysis_preferences.dart';
import '../models/capture_input.dart';
import '../models/user_preferences.dart';
import '../models/vibe_result.dart';

abstract class VibeAnalyzer {
  Future<VibeResult> analyze({
    required CaptureInput capture,
    required AnalysisPreferences preferences,
    required UserPreferences userPreferences,
    Uint8List? mediaBytes,
  });
}

// Production boundary:
// Flutter sends user-approved media to the configured backend only. Secrets,
// vector search, model calls, and Spotify ingestion stay server-side.
