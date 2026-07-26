class PresetTask {
  final String id;
  final String name;
  final String? defaultDescription;
  final bool requireCarOrThing;
  final String? createdBy;

  PresetTask({
    required this.id,
    required this.name,
    this.defaultDescription,
    this.requireCarOrThing = false,
    this.createdBy,
  });

  factory PresetTask.fromMap(Map<String, dynamic> map, String docId) {
    return PresetTask(
      id: docId,
      name: map['name'] as String? ?? '',
      defaultDescription: map['defaultDescription'] as String?,
      requireCarOrThing: map['requireCarOrThing'] as bool? ?? false,
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'defaultDescription': defaultDescription,
      'requireCarOrThing': requireCarOrThing,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}
