<?php

const TT_PROJECT_ID = 'task-tracker-6d7e1';
const TT_WEB_API_KEY = 'AIzaSyCq3-FOmjHuQH86QfA5Vf7c8hyneS0nbC0';
const TT_AUTH_API = 'https://identitytoolkit.googleapis.com/v1';
const TT_FIRESTORE_API = 'https://firestore.googleapis.com/v1/projects/task-tracker-6d7e1/databases/(default)/documents';

const TT_SECRETS_DIR = __DIR__ . '/../secrets';

function tt_passphrase(): string {
    return require TT_SECRETS_DIR . '/passphrase.php';
}

function tt_service_account(): array {
    $json = @file_get_contents(TT_SECRETS_DIR . '/service-account.json');
    $data = $json ? json_decode($json, true) : null;
    if (!is_array($data) || empty($data['client_email']) || empty($data['private_key'])) {
        throw new RuntimeException('Missing or invalid service-account.json');
    }
    return $data;
}

function tt_json_error(string $message, int $status = 400): never {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => $message]);
    exit;
}
