class VibeDiaryEntry {
  const VibeDiaryEntry({
    required this.resultId,
    required this.vibeName,
    required this.date,
    required this.moodTags,
    required this.quote,
    required this.confidence,
    required this.paletteHex,
  });

  final String resultId;
  final String vibeName;
  final DateTime date;
  final List<String> moodTags;
  final String quote;
  final double confidence;
  final List<String> paletteHex;
}
