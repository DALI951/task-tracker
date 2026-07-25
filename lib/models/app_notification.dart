class AppNotification {
  final String id;
  final String recipientEmail;
  final String type;
  final String title;
  final String message;
  final String senderName;
  final bool read;
  final DateTime createdAt;
  final String? relatedId;

  AppNotification({
    required this.id,
    required this.recipientEmail,
    required this.type,
    required this.title,
    required this.message,
    this.senderName = '',
    this.read = false,
    required this.createdAt,
    this.relatedId,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    return AppNotification(
      id: docId,
      recipientEmail: map['recipientEmail'] as String? ?? '',
      type: map['type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      relatedId: map['relatedId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientEmail': recipientEmail,
      'type': type,
      'title': title,
      'message': message,
      'senderName': senderName,
      'read': read,
      'createdAt': createdAt,
      'relatedId': relatedId,
    };
  }
}
