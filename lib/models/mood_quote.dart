class MoodQuote {
  const MoodQuote({
    required this.text,
    required this.source,
    required this.isAiGenerated,
  });

  final String text;
  final String source;
  final bool isAiGenerated;

  Map<String, dynamic> toJson() => {
    'text': text,
    'source': source,
    'isAiGenerated': isAiGenerated,
  };

  factory MoodQuote.fromJson(Map<String, dynamic> json) {
    return MoodQuote(
      text: json['text'] as String,
      source: json['source'] as String,
      isAiGenerated: json['isAiGenerated'] as bool? ?? true,
    );
  }
}
