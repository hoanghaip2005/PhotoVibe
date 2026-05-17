import 'song.dart';

class VibePlaylist {
  const VibePlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.moodTags,
    required this.paletteHex,
    required this.songs,
    this.spotifyUrl,
    this.isSaved = false,
  });

  final String id;
  final String name;
  final String description;
  final List<String> moodTags;
  final List<String> paletteHex;
  final List<Song> songs;
  final String? spotifyUrl;
  final bool isSaved;

  VibePlaylist copyWith({bool? isSaved, List<Song>? songs}) {
    return VibePlaylist(
      id: id,
      name: name,
      description: description,
      moodTags: moodTags,
      paletteHex: paletteHex,
      songs: songs ?? this.songs,
      spotifyUrl: spotifyUrl,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'moodTags': moodTags,
    'paletteHex': paletteHex,
    'songs': songs.map((song) => song.toJson()).toList(),
    'spotifyUrl': spotifyUrl,
    'isSaved': isSaved,
  };

  factory VibePlaylist.fromJson(Map<String, dynamic> json) {
    return VibePlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      moodTags: (json['moodTags'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      paletteHex: (json['paletteHex'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      songs: (json['songs'] as List<dynamic>? ?? const [])
          .map((item) => Song.fromJson(item as Map<String, dynamic>))
          .toList(),
      spotifyUrl: json['spotifyUrl'] as String?,
      isSaved: json['isSaved'] as bool? ?? false,
    );
  }
}
