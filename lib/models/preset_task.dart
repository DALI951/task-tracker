class PresetTask {
  final String id;
  final String name;
  final String? defaultDescription;
  final bool requireCarOrThing;

  PresetTask({
    required this.id,
    required this.name,
    this.defaultDescription,
    this.requireCarOrThing = false,
  });

  factory PresetTask.fromMap(Map<String, dynamic> map, String docId) {
    return PresetTask(
      id: docId,
      name: map['name'] as String? ?? '',
      defaultDescription: map['defaultDescription'] as String?,
      requireCarOrThing: map['requireCarOrThing'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'defaultDescription': defaultDescription,
      'requireCarOrThing': requireCarOrThing,
    };
  }
}
