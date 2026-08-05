<?php

require_once __DIR__ . '/../lib/firebase.php';

// CORS: the web build runs on dali951.github.io (https).
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-App-Secret');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    tt_json_error('Method not allowed', 405);
}

// Without the shared secret, anyone could spam push notifications to any
// stored FCM token.
tt_require_app_secret();

$raw = file_get_contents('php://input');
$data = json_decode($raw ?: '', true);
if (!is_array($data)) {
    tt_json_error('Invalid JSON body');
}

$token = trim((string) ($data['token'] ?? ''));
$title = trim((string) ($data['title'] ?? ''));
$body = trim((string) ($data['body'] ?? ''));
$extra = $data['data'] ?? null;

if ($token === '' || $title === '') {
    tt_json_error('token and title are required');
}

try {
    $accessToken = tt_firestore_access_token();

    $message = [
        'message' => [
            'token' => $token,
            'notification' => ['title' => $title, 'body' => $body],
            'android' => [
                'priority' => 'high',
                'notification' => ['channel_id' => 'task_tracker_channel'],
            ],
        ],
    ];
    if (is_array($extra)) {
        $clean = [];
        foreach ($extra as $k => $v) {
            if (is_scalar($v)) {
                $clean[(string) $k] = (string) $v;
            }
        }
        if ($clean !== []) {
            $message['message']['data'] = $clean;
        }
    }

    [$code, $resp] = tt_http_json(
        'https://fcm.googleapis.com/v1/projects/' . TT_PROJECT_ID . '/messages:send',
        'POST',
        $message,
        ['Authorization: Bearer ' . $accessToken]
    );

    if ($code >= 200 && $code < 300) {
        header('Content-Type: application/json');
        echo json_encode(['ok' => true]);
    } else {
        http_response_code(502);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'FCM error ' . $code . ': ' . json_encode($resp)]);
    }
} catch (RuntimeException $e) {
    tt_json_error($e->getMessage(), 502);
}
