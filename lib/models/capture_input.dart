enum CaptureType { image }

class CaptureInput {
  const CaptureInput({
    required this.id,
    required this.type,
    required this.mediaPaths,
    required this.createdAt,
    this.label,
  });

  final String id;
  final CaptureType type;
  final List<String> mediaPaths;
  final DateTime createdAt;
  final String? label;

  bool get hasMedia => mediaPaths.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'mediaPaths': mediaPaths,
    'createdAt': createdAt.toIso8601String(),
    'label': label,
  };

  factory CaptureInput.fromJson(Map<String, dynamic> json) {
    return CaptureInput(
      id: json['id'] as String,
      type: CaptureType.values.byName(json['type'] as String),
      mediaPaths: (json['mediaPaths'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      label: json['label'] as String?,
    );
  }
}
