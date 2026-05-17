class FilterPreset {
  const FilterPreset({
    required this.id,
    required this.name,
    required this.paletteHex,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.warmth,
    required this.fade,
    required this.grain,
    required this.vignette,
    this.isSaved = false,
  });

  final String id;
  final String name;
  final List<String> paletteHex;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final double fade;
  final double grain;
  final double vignette;
  final bool isSaved;

  FilterPreset copyWith({
    String? id,
    String? name,
    List<String>? paletteHex,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? fade,
    double? grain,
    double? vignette,
    bool? isSaved,
  }) {
    return FilterPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      paletteHex: paletteHex ?? this.paletteHex,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
      fade: fade ?? this.fade,
      grain: grain ?? this.grain,
      vignette: vignette ?? this.vignette,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'paletteHex': paletteHex,
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'warmth': warmth,
    'fade': fade,
    'grain': grain,
    'vignette': vignette,
    'isSaved': isSaved,
  };

  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      paletteHex: (json['paletteHex'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      brightness: (json['brightness'] as num).toDouble(),
      contrast: (json['contrast'] as num).toDouble(),
      saturation: (json['saturation'] as num).toDouble(),
      warmth: (json['warmth'] as num).toDouble(),
      fade: (json['fade'] as num).toDouble(),
      grain: (json['grain'] as num).toDouble(),
      vignette: (json['vignette'] as num).toDouble(),
      isSaved: json['isSaved'] as bool? ?? false,
    );
  }
}
