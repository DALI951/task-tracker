class PresetItem {
  final String id;
  final String name;

  PresetItem({required this.id, required this.name});

  factory PresetItem.fromMap(Map<String, dynamic> map, String docId) {
    return PresetItem(
      id: docId,
      name: map['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name};
  }
}
