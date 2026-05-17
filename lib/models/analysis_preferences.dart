enum AnalysisMode { autoVibe, musicFirst, quoteFirst, filterFirst, deepMood }

extension AnalysisModeCopy on AnalysisMode {
  String get label => switch (this) {
    AnalysisMode.autoVibe => 'Auto Vibe',
    AnalysisMode.musicFirst => 'Music First',
    AnalysisMode.quoteFirst => 'Quote First',
    AnalysisMode.filterFirst => 'Filter First',
    AnalysisMode.deepMood => 'Deep Mood',
  };

  String get apiValue => switch (this) {
    AnalysisMode.autoVibe => 'auto',
    AnalysisMode.musicFirst => 'music_first',
    AnalysisMode.quoteFirst => 'quote_first',
    AnalysisMode.filterFirst => 'filter_first',
    AnalysisMode.deepMood => 'deep_mood',
  };
}

class AnalysisPreferences {
  const AnalysisPreferences({
    required this.hint,
    required this.mode,
    required this.moodHints,
  });

  final String hint;
  final AnalysisMode mode;
  final List<String> moodHints;

  static const empty = AnalysisPreferences(
    hint: '',
    mode: AnalysisMode.autoVibe,
    moodHints: [],
  );

  AnalysisPreferences copyWith({
    String? hint,
    AnalysisMode? mode,
    List<String>? moodHints,
  }) {
    return AnalysisPreferences(
      hint: hint ?? this.hint,
      mode: mode ?? this.mode,
      moodHints: moodHints ?? this.moodHints,
    );
  }

  Map<String, dynamic> toJson() => {
    'hint': hint,
    'mode': mode.name,
    'moodHints': moodHints,
  };

  factory AnalysisPreferences.fromJson(Map<String, dynamic> json) {
    return AnalysisPreferences(
      hint: json['hint'] as String? ?? '',
      mode: AnalysisMode.values.byName(
        json['mode'] as String? ?? AnalysisMode.autoVibe.name,
      ),
      moodHints: (json['moodHints'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}
