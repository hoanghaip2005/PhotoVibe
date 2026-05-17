import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis_preferences.dart';
import '../models/capture_input.dart';
import '../models/filter_preset.dart';
import '../models/playlist.dart';
import '../models/user_preferences.dart';
import '../models/vibe_diary_entry.dart';
import '../models/vibe_result.dart';
import '../services/backend_vibe_analyzer_service.dart';
import '../services/vibe_analyzer.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences override missing');
});

final vibeAnalyzerProvider = Provider<VibeAnalyzer>((ref) {
  return BackendVibeAnalyzerService();
});

final appStateProvider = ChangeNotifierProvider<VibeAppState>((ref) {
  return VibeAppState(
    preferences: ref.watch(sharedPreferencesProvider),
    analyzer: ref.watch(vibeAnalyzerProvider),
  )..load();
});

class VibeAppState extends ChangeNotifier {
  VibeAppState({
    required SharedPreferences preferences,
    required VibeAnalyzer analyzer,
  }) : _preferences = preferences,
       _analyzer = analyzer;

  static const _onboardingKey = 'vibelens.onboardingCompleted';
  static const _authPromptCompletedKey = 'vibelens.authPromptCompleted';
  static const _musicProfileCompletedKey = 'vibelens.musicProfileCompleted';
  static const _resultsKey = 'vibelens.results';
  static const _savedPlaylistIdsKey = 'vibelens.savedPlaylistIds';
  static const _savedFiltersKey = 'vibelens.savedFilters';
  static const _userPreferencesKey = 'vibelens.userPreferences';
  static const _anonymousIdKey = 'vibelens.anonymousId';

  final SharedPreferences _preferences;
  final VibeAnalyzer _analyzer;

  bool onboardingCompleted = false;
  bool authPromptCompleted = false;
  bool musicProfileCompleted = false;
  bool isAnalyzing = false;
  String? lastError;
  CaptureInput? currentCapture;
  AnalysisPreferences currentAnalysisPreferences = AnalysisPreferences.empty;
  Uint8List? currentMediaBytes;
  VibeResult? currentResult;
  UserPreferences userPreferences = UserPreferences.defaults;

  final List<VibeResult> _results = [];
  final Set<String> _savedPlaylistIds = {};
  final List<FilterPreset> _savedFilters = [];

  List<VibeResult> get results => List.unmodifiable(_results);

  List<VibeResult> get savedResults =>
      _results.where((result) => result.isSaved).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<VibeDiaryEntry> get diaryEntries {
    return savedResults
        .map(
          (result) => VibeDiaryEntry(
            resultId: result.id,
            vibeName: result.vibeName,
            date: result.createdAt,
            moodTags: result.moodTags,
            quote: result.quote.text,
            confidence: result.confidence,
            paletteHex: result.paletteHex,
          ),
        )
        .toList();
  }

  List<VibePlaylist> get savedPlaylists {
    final playlists = <String, VibePlaylist>{};
    for (final result in _results) {
      if (_savedPlaylistIds.contains(result.playlist.id) ||
          result.playlist.isSaved) {
        playlists[result.playlist.id] = result.playlist.copyWith(isSaved: true);
      }
    }
    return playlists.values.toList();
  }

  List<FilterPreset> get savedFilters => List.unmodifiable(_savedFilters);

  void load() {
    onboardingCompleted = _preferences.getBool(_onboardingKey) ?? false;
    musicProfileCompleted =
        _preferences.getBool(_musicProfileCompletedKey) ?? false;
    final storedAuthPromptCompleted = _preferences.getBool(
      _authPromptCompletedKey,
    );
    authPromptCompleted = storedAuthPromptCompleted ?? musicProfileCompleted;
    if (storedAuthPromptCompleted == null && musicProfileCompleted) {
      _preferences.setBool(_authPromptCompletedKey, true);
    }
    _savedPlaylistIds
      ..clear()
      ..addAll(_preferences.getStringList(_savedPlaylistIdsKey) ?? const []);

    final userJson = _preferences.getString(_userPreferencesKey);
    final anonymousId =
        _preferences.getString(_anonymousIdKey) ??
        'anon_${DateTime.now().microsecondsSinceEpoch}';
    _preferences.setString(_anonymousIdKey, anonymousId);
    if (userJson != null) {
      userPreferences = UserPreferences.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      ).copyWith(anonymousId: anonymousId);
    } else {
      userPreferences = UserPreferences.defaults.copyWith(
        anonymousId: anonymousId,
      );
    }

    final resultsJson = _preferences.getString(_resultsKey);
    if (resultsJson != null) {
      final decoded = jsonDecode(resultsJson) as List<dynamic>;
      _results
        ..clear()
        ..addAll(
          decoded.map(
            (item) => VibeResult.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    final filtersJson = _preferences.getString(_savedFiltersKey);
    if (filtersJson != null) {
      final decoded = jsonDecode(filtersJson) as List<dynamic>;
      _savedFilters
        ..clear()
        ..addAll(
          decoded.map(
            (item) => FilterPreset.fromJson(item as Map<String, dynamic>),
          ),
        );
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    await _preferences.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> completeAuthPrompt() async {
    authPromptCompleted = true;
    await _preferences.setBool(_authPromptCompletedKey, true);
    notifyListeners();
  }

  Future<void> signInWithEmail({
    required String email,
    required String displayName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = displayName.trim().isEmpty
        ? cleanEmail.split('@').first
        : displayName.trim();
    userPreferences = userPreferences.copyWith(
      email: cleanEmail,
      displayName: cleanName,
      isSignedIn: true,
    );
    authPromptCompleted = true;
    await _preferences.setString(
      _userPreferencesKey,
      jsonEncode(userPreferences.toJson()),
    );
    await _preferences.setBool(_authPromptCompletedKey, true);
    notifyListeners();
  }

  Future<void> signOutAccount() async {
    userPreferences = userPreferences.copyWith(
      email: '',
      isSignedIn: false,
      displayName: UserPreferences.defaults.displayName,
    );
    authPromptCompleted = true;
    await _preferences.setString(
      _userPreferencesKey,
      jsonEncode(userPreferences.toJson()),
    );
    await _preferences.setBool(_authPromptCompletedKey, true);
    notifyListeners();
  }

  Future<void> completeMusicProfileSetup() async {
    musicProfileCompleted = true;
    await _preferences.setBool(_musicProfileCompletedKey, true);
    notifyListeners();
  }

  void startCapture(CaptureInput capture, {Uint8List? mediaBytes}) {
    currentCapture = capture;
    currentMediaBytes = mediaBytes;
    currentAnalysisPreferences = AnalysisPreferences.empty;
    lastError = null;
    notifyListeners();
  }

  void updateAnalysisPreferences(AnalysisPreferences preferences) {
    currentAnalysisPreferences = preferences;
    notifyListeners();
  }

  Future<VibeResult?> analyzeCurrentCapture() async {
    final capture = currentCapture;
    if (capture == null || !capture.hasMedia) {
      lastError = 'Chưa có media để phân tích.';
      notifyListeners();
      return null;
    }

    isAnalyzing = true;
    lastError = null;
    notifyListeners();

    try {
      final result = await _analyzer.analyze(
        capture: capture,
        preferences: currentAnalysisPreferences,
        userPreferences: userPreferences,
        mediaBytes: currentMediaBytes,
      );
      _upsertResult(result);
      currentResult = result;
      await _persistResults();
      return result;
    } catch (error) {
      lastError = error.toString();
      return null;
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
  }

  VibeResult? resultById(String id) {
    return _results.where((result) => result.id == id).firstOrNull;
  }

  VibePlaylist? playlistById(String id) {
    for (final result in _results) {
      if (result.playlist.id == id) {
        return result.playlist;
      }
    }
    return null;
  }

  Future<void> saveResult(String id) async {
    final result = resultById(id);
    if (result == null) return;
    final saved = result.copyWith(
      isSaved: true,
      playlist: result.playlist.copyWith(isSaved: true),
    );
    _savedPlaylistIds.add(saved.playlist.id);
    _upsertResult(saved);
    currentResult = saved;
    await _persistResults();
    await _preferences.setStringList(
      _savedPlaylistIdsKey,
      _savedPlaylistIds.toList(),
    );
    notifyListeners();
  }

  Future<void> savePlaylist(String id) async {
    _savedPlaylistIds.add(id);
    for (final result in _results) {
      if (result.playlist.id == id) {
        _upsertResult(
          result.copyWith(playlist: result.playlist.copyWith(isSaved: true)),
        );
        break;
      }
    }
    await _persistResults();
    await _preferences.setStringList(
      _savedPlaylistIdsKey,
      _savedPlaylistIds.toList(),
    );
    notifyListeners();
  }

  Future<void> regeneratePlaylist(String resultId) async {
    final result = resultById(resultId);
    if (result == null) return;
    final regenerated = await _analyzer.analyze(
      capture: result.capture,
      preferences: currentAnalysisPreferences.copyWith(
        hint: '${currentAnalysisPreferences.hint} tạo lại playlist',
        mode: AnalysisMode.musicFirst,
      ),
      userPreferences: userPreferences,
      mediaBytes: currentMediaBytes,
    );
    final updated = result.copyWith(playlist: regenerated.playlist);
    _upsertResult(updated);
    currentResult = updated;
    await _persistResults();
    notifyListeners();
  }

  Future<void> saveFilter(FilterPreset preset) async {
    final saved = preset.copyWith(
      id: preset.id.startsWith('saved_')
          ? preset.id
          : 'saved_${DateTime.now().microsecondsSinceEpoch}',
      isSaved: true,
    );
    final existingIndex = _savedFilters.indexWhere(
      (filter) => filter.name == saved.name,
    );
    if (existingIndex >= 0) {
      _savedFilters[existingIndex] = saved;
    } else {
      _savedFilters.add(saved);
    }
    await _persistFilters();
    notifyListeners();
  }

  Future<void> updateUserPreferences(UserPreferences preferences) async {
    userPreferences = preferences;
    musicProfileCompleted = true;
    await _preferences.setString(
      _userPreferencesKey,
      jsonEncode(preferences.toJson()),
    );
    await _preferences.setBool(_musicProfileCompletedKey, true);
    notifyListeners();
  }

  void _upsertResult(VibeResult result) {
    final index = _results.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      _results[index] = result;
    } else {
      _results.add(result);
    }
  }

  Future<void> _persistResults() {
    return _preferences.setString(
      _resultsKey,
      jsonEncode(_results.map((result) => result.toJson()).toList()),
    );
  }

  Future<void> _persistFilters() {
    return _preferences.setString(
      _savedFiltersKey,
      jsonEncode(_savedFilters.map((filter) => filter.toJson()).toList()),
    );
  }
}
