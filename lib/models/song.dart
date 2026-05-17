class Song {
  const Song({
    required this.title,
    required this.artist,
    required this.matchPercent,
    required this.reason,
    required this.genres,
    this.spotifyUrl,
    this.spotifySearchUrl,
  });

  final String title;
  final String artist;
  final int matchPercent;
  final String reason;
  final List<String> genres;
  final String? spotifyUrl;
  final String? spotifySearchUrl;

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'matchPercent': matchPercent,
    'reason': reason,
    'genres': genres,
    'spotifyUrl': spotifyUrl,
    'spotifySearchUrl': spotifySearchUrl,
  };

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json['title'] as String,
      artist: json['artist'] as String,
      matchPercent: json['matchPercent'] as int,
      reason: json['reason'] as String,
      genres: (json['genres'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      spotifyUrl: json['spotifyUrl'] as String?,
      spotifySearchUrl: json['spotifySearchUrl'] as String?,
    );
  }
}
