<?php

require_once __DIR__ . '/config.php';

function tt_b64url(string $s): string {
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}

function tt_http_json(string $url, string $method, array $payload = [], array $headers = []): array {
    $ch = curl_init($url);
    $opts = [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json'], $headers),
    ];
    if ($method === 'POST' || $method === 'PATCH') {
        $opts[CURLOPT_CUSTOMREQUEST] = $method;
        $opts[CURLOPT_POSTFIELDS] = json_encode($payload);
    }
    curl_setopt_array($ch, $opts);
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    if ($err !== '') {
        throw new RuntimeException('Network error: ' . $err);
    }
    return [$code, json_decode($body ?: '', true) ?: []];
}

function tt_sign_jwt(array $claims): string {
    $sa = tt_service_account();
    $header = tt_b64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $payload = tt_b64url(json_encode($claims));
    $signingInput = $header . '.' . $payload;
    if (!openssl_sign($signingInput, $signature, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('Could not sign JWT');
    }
    return $signingInput . '.' . tt_b64url($signature);
}

function tt_firestore_access_token(): string {
    $sa = tt_service_account();
    $now = time();
    $jwt = tt_sign_jwt([
        'iss' => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/cloud-platform',
        'aud' => $sa['token_uri'],
        'iat' => $now,
        'exp' => $now + 3600,
    ]);
    $ch = curl_init($sa['token_uri']);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]),
        CURLOPT_TIMEOUT => 20,
    ]);
    $body = curl_exec($ch);
    curl_close($ch);
    $data = json_decode($body ?: '', true) ?: [];
    if (empty($data['access_token'])) {
        throw new RuntimeException('Could not mint Google access token');
    }
    return $data['access_token'];
}

function tt_create_auth_user(string $email, string $password): string {
    [$code, $data] = tt_http_json(TT_AUTH_API . '/accounts:signUp?key=' . TT_WEB_API_KEY, 'POST', [
        'email' => $email,
        'password' => $password,
        'returnSecureToken' => true,
    ]);
    if ($code < 200 || $code >= 300) {
        $msg = $data['error']['message'] ?? 'Failed to create account';
        if (str_contains($msg, 'EMAIL_EXISTS')) {
            $msg = 'An account with this email already exists.';
        }
        throw new RuntimeException($msg);
    }
    return $data['localId'];
}

function tt_firestore_fields(array $data): array {
    $out = [];
    foreach ($data as $key => $value) {
        if ($value instanceof DateTimeInterface) {
            $out[$key] = ['timestampValue' => $value->format('Y-m-d\TH:i:s\Z')];
        } elseif (is_string($value)) {
            $out[$key] = ['stringValue' => $value];
        } elseif (is_bool($value)) {
            $out[$key] = ['booleanValue' => $value];
        } elseif (is_int($value) || is_float($value)) {
            $out[$key] = ['integerValue' => (string) $value];
        } elseif (is_array($value)) {
            $out[$key] = ['mapValue' => ['fields' => tt_firestore_fields($value)]];
        } elseif ($value === null) {
            $out[$key] = ['nullValue' => null];
        } else {
            $out[$key] = ['stringValue' => (string) $value];
        }
    }
    return $out;
}

function tt_set_user_doc(string $uid, array $fields): void {
    $masks = [];
    foreach (array_keys($fields) as $key) {
        $masks[] = 'updateMask.fieldPaths=' . urlencode($key);
    }
    $url = TT_FIRESTORE_API . '/users/' . $uid . '?' . implode('&', $masks);
    $token = tt_firestore_access_token();
    [$code, $data] = tt_http_json($url, 'PATCH', ['fields' => tt_firestore_fields($fields)], [
        'Authorization: Bearer ' . $token,
    ]);
    if ($code < 200 || $code >= 300) {
        throw new RuntimeException('Could not save manager role (code ' . $code . ')');
    }
}
