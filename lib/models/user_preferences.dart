class UserPreferences {
  const UserPreferences({
    required this.anonymousId,
    required this.email,
    required this.displayName,
    required this.isSignedIn,
    required this.gender,
    required this.ageGroup,
    required this.preferredGenres,
    required this.preferredLanguages,
    required this.musicEraPreference,
    required this.favoriteArtists,
    required this.favoriteSongs,
    required this.explicitContentAllowed,
    required this.discoveryLevel,
    required this.quoteLanguage,
    required this.spotifyConnected,
    required this.darkMode,
  });

  final String anonymousId;
  final String email;
  final String displayName;
  final bool isSignedIn;
  final String gender;
  final String ageGroup;
  final List<String> preferredGenres;
  final List<String> preferredLanguages;
  final String musicEraPreference;
  final List<String> favoriteArtists;
  final List<String> favoriteSongs;
  final bool explicitContentAllowed;
  final String discoveryLevel;
  final String quoteLanguage;
  final bool spotifyConnected;
  final bool darkMode;

  static const defaults = UserPreferences(
    anonymousId: 'anonymous_local',
    email: '',
    displayName: 'VibeLens',
    isSignedIn: false,
    gender: 'unknown',
    ageGroup: 'unknown',
    preferredGenres: [],
    preferredLanguages: [],
    musicEraPreference: 'mood_based',
    favoriteArtists: [],
    favoriteSongs: [],
    explicitContentAllowed: false,
    discoveryLevel: 'balanced',
    quoteLanguage: 'Tiếng Việt',
    spotifyConnected: false,
    darkMode: false,
  );

  UserPreferences copyWith({
    String? anonymousId,
    String? email,
    String? displayName,
    bool? isSignedIn,
    String? gender,
    String? ageGroup,
    List<String>? preferredGenres,
    List<String>? preferredLanguages,
    String? musicEraPreference,
    List<String>? favoriteArtists,
    List<String>? favoriteSongs,
    bool? explicitContentAllowed,
    String? discoveryLevel,
    String? quoteLanguage,
    bool? spotifyConnected,
    bool? darkMode,
  }) {
    return UserPreferences(
      anonymousId: anonymousId ?? this.anonymousId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      musicEraPreference: musicEraPreference ?? this.musicEraPreference,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      favoriteSongs: favoriteSongs ?? this.favoriteSongs,
      explicitContentAllowed:
          explicitContentAllowed ?? this.explicitContentAllowed,
      discoveryLevel: discoveryLevel ?? this.discoveryLevel,
      quoteLanguage: quoteLanguage ?? this.quoteLanguage,
      spotifyConnected: spotifyConnected ?? this.spotifyConnected,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'anonymousId': anonymousId,
    'email': email,
    'displayName': displayName,
    'isSignedIn': isSignedIn,
    'gender': gender,
    'ageGroup': ageGroup,
    'preferredGenres': preferredGenres,
    'preferredLanguages': preferredLanguages,
    'musicEraPreference': musicEraPreference,
    'favoriteArtists': favoriteArtists,
    'favoriteSongs': favoriteSongs,
    'explicitContentAllowed': explicitContentAllowed,
    'discoveryLevel': discoveryLevel,
    'quoteLanguage': quoteLanguage,
    'spotifyConnected': spotifyConnected,
    'darkMode': darkMode,
  };

  Map<String, dynamic> toBackendJson() => {
    'gender': gender,
    'age_group': ageGroup,
    'preferred_genres': preferredGenres.map(_normalizeGenre).toList(),
    'preferred_languages': preferredLanguages,
    'music_era_preference': musicEraPreference,
    'favorite_artists': favoriteArtists,
    'favorite_songs': favoriteSongs,
    'explicit_content_allowed': explicitContentAllowed,
    'discovery_level': discoveryLevel,
  };

  bool get hasProductionMusicProfile {
    return gender != 'unknown' ||
        ageGroup != 'unknown' ||
        preferredGenres.isNotEmpty ||
        preferredLanguages.isNotEmpty ||
        favoriteArtists.isNotEmpty ||
        favoriteSongs.isNotEmpty;
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      anonymousId: json['anonymousId'] as String? ?? defaults.anonymousId,
      email: json['email'] as String? ?? defaults.email,
      displayName: json['displayName'] as String? ?? defaults.displayName,
      isSignedIn: json['isSignedIn'] as bool? ?? defaults.isSignedIn,
      gender: json['gender'] as String? ?? defaults.gender,
      ageGroup: json['ageGroup'] as String? ?? defaults.ageGroup,
      preferredGenres:
          (json['preferredGenres'] as List<dynamic>? ??
                  defaults.preferredGenres)
              .map((item) => item as String)
              .toList(),
      preferredLanguages:
          (json['preferredLanguages'] as List<dynamic>? ??
                  defaults.preferredLanguages)
              .map((item) => item as String)
              .toList(),
      musicEraPreference:
          json['musicEraPreference'] as String? ?? defaults.musicEraPreference,
      favoriteArtists:
          (json['favoriteArtists'] as List<dynamic>? ??
                  defaults.favoriteArtists)
              .map((item) => item as String)
              .toList(),
      favoriteSongs:
          (json['favoriteSongs'] as List<dynamic>? ?? defaults.favoriteSongs)
              .map((item) => item as String)
              .toList(),
      explicitContentAllowed:
          json['explicitContentAllowed'] as bool? ??
          defaults.explicitContentAllowed,
      discoveryLevel:
          json['discoveryLevel'] as String? ?? defaults.discoveryLevel,
      quoteLanguage: json['quoteLanguage'] as String? ?? defaults.quoteLanguage,
      spotifyConnected:
          json['spotifyConnected'] as bool? ?? defaults.spotifyConnected,
      darkMode: json['darkMode'] as bool? ?? defaults.darkMode,
    );
  }

  static String _normalizeGenre(String value) {
    return value.toLowerCase().replaceAll(' ', '_');
  }
}
