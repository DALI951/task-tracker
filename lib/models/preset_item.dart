class PresetItem {
  final String id;
  final String name;
  final String? createdBy;

  PresetItem({required this.id, required this.name, this.createdBy});

  factory PresetItem.fromMap(Map<String, dynamic> map, String docId) {
    return PresetItem(
      id: docId,
      name: map['name'] as String? ?? '',
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}
