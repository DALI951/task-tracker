/// Shared secret between the app and the PHP API endpoints
/// (upload-photo.php, send-push.php). Sent as the `X-App-Secret` header.
///
/// Must match `TT_APP_SECRET` in `server/lib/config.php`. Override at build
/// time without touching code:
///   flutter build apk --release --dart-define=APP_SECRET=...
const String appSecret = String.fromEnvironment(
  'APP_SECRET',
  defaultValue:
      'E39C52EB7778DB3CF8ED06DE99E2BB5F57433EEDFA4A871A29CDA49C7BC61AB0',
);