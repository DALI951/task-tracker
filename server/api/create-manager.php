<?php

require_once __DIR__ . '/../lib/firebase.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    tt_json_error('Method not allowed', 405);
}

$raw = file_get_contents('php://input');
$data = json_decode($raw ?: '', true);
if (!is_array($data)) {
    tt_json_error('Invalid JSON body');
}

$passphrase = trim((string) ($data['passphrase'] ?? ''));
$name = trim((string) ($data['name'] ?? ''));
$email = strtolower(trim((string) ($data['email'] ?? '')));
$password = (string) ($data['password'] ?? '');

if ($passphrase === '' || !hash_equals(tt_passphrase(), $passphrase)) {
    tt_json_error('Wrong passphrase', 403);
}
if ($name === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    tt_json_error('A valid name and email are required');
}
if (strlen($password) < 6) {
    tt_json_error('Password must be at least 6 characters');
}

try {
    $uid = tt_create_auth_user($email, $password);
    tt_set_user_doc($uid, [
        'role' => 'manager',
        'email' => $email,
        'name' => $name,
        'displayName' => $name,
        'createdAt' => new DateTime('now', new DateTimeZone('UTC')),
    ]);
    header('Content-Type: application/json');
    echo json_encode(['ok' => true, 'message' => 'Account created']);
} catch (RuntimeException $e) {
    tt_json_error($e->getMessage(), 409);
}
