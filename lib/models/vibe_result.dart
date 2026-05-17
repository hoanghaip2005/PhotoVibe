import 'capture_input.dart';
import 'filter_preset.dart';
import 'mood_quote.dart';
import 'playlist.dart';

class VibeResult {
  const VibeResult({
    required this.id,
    required this.capture,
    required this.vibeName,
    required this.description,
    required this.moodTags,
    required this.sceneTags,
    required this.confidence,
    required this.paletteHex,
    required this.playlist,
    required this.quote,
    required this.filters,
    required this.createdAt,
    this.isSaved = false,
  });

  final String id;
  final CaptureInput capture;
  final String vibeName;
  final String description;
  final List<String> moodTags;
  final List<String> sceneTags;
  final double confidence;
  final List<String> paletteHex;
  final VibePlaylist playlist;
  final MoodQuote quote;
  final List<FilterPreset> filters;
  final DateTime createdAt;
  final bool isSaved;

  VibeResult copyWith({
    VibePlaylist? playlist,
    List<FilterPreset>? filters,
    bool? isSaved,
  }) {
    return VibeResult(
      id: id,
      capture: capture,
      vibeName: vibeName,
      description: description,
      moodTags: moodTags,
      sceneTags: sceneTags,
      confidence: confidence,
      paletteHex: paletteHex,
      playlist: playlist ?? this.playlist,
      quote: quote,
      filters: filters ?? this.filters,
      createdAt: createdAt,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'capture': capture.toJson(),
    'vibeName': vibeName,
    'description': description,
    'moodTags': moodTags,
    'sceneTags': sceneTags,
    'confidence': confidence,
    'paletteHex': paletteHex,
    'playlist': playlist.toJson(),
    'quote': quote.toJson(),
    'filters': filters.map((filter) => filter.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'isSaved': isSaved,
  };

  factory VibeResult.fromJson(Map<String, dynamic> json) {
    return VibeResult(
      id: json['id'] as String,
      capture: CaptureInput.fromJson(json['capture'] as Map<String, dynamic>),
      vibeName: json['vibeName'] as String,
      description: json['description'] as String,
      moodTags: (json['moodTags'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      sceneTags: (json['sceneTags'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
      paletteHex: (json['paletteHex'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      playlist: VibePlaylist.fromJson(json['playlist'] as Map<String, dynamic>),
      quote: MoodQuote.fromJson(json['quote'] as Map<String, dynamic>),
      filters: (json['filters'] as List<dynamic>? ?? const [])
          .map((item) => FilterPreset.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isSaved: json['isSaved'] as bool? ?? false,
    );
  }
}
