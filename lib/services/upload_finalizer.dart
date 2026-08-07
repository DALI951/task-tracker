import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/services/firestore_service.dart';
import 'package:task_tracker/services/notification_service.dart';
import 'package:task_tracker/services/upload_session.dart';

/// Applies the final document flip + push after every photo of a session has
/// been uploaded. Shared by the background worker and the in-app
/// reconciliation so both paths behave identically.
class UploadFinalizer {
  /// Returns false if the final write failed (permissions/network). The
  /// caller should then keep the session around for a later retry.
  static Future<bool> apply(UploadSession session) async {
    try {
      final urls = session.photos
          .map((p) => p.url)
          .where((u) => u.isNotEmpty)
          .toList();
      final fs = FirestoreService();

      if (session.type == 'task_completion') {
        await fs.updateTask(session.docId, {
          'status': session.approveDirectly ? 'completed' : 'pending_review',
          'photoUrl': urls.isEmpty ? null : urls.first,
          'photoUrls': urls,
          'completionDescription': session.completionDescription,
          'uploadsComplete': true,
          'uploadCompleted': urls.length,
          'uploadTotal': session.photos.length,
          'completedAt': DateTime.now(),
          'approvedBy': session.approveDirectly ? session.actorEmail : null,
          'rejectionReason': null,
        });
        await fs.appendHistory(
          session.docId,
          HistoryEvent(
            action: session.historyAction,
            by: session.historyBy,
            detail: '',
            at: DateTime.now(),
          ).toMap(),
        );
      } else {
        await fs.updateProblem(session.docId, {
          'status': 'open',
          'photoUrl': urls.isEmpty ? null : urls.first,
          'photoUrls': urls,
          'uploadsComplete': true,
          'uploadCompleted': urls.length,
          'uploadTotal': session.photos.length,
        });
      }

      if (session.pushRecipientEmail.isNotEmpty) {
        await NotificationService().send(
          recipientEmail: session.pushRecipientEmail,
          type: session.pushType,
          title: session.pushTitle,
          message: session.pushMessage,
          relatedId: session.docId,
          senderName: session.pushSenderName,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
