<?php

require_once __DIR__ . '/../lib/config.php';

// Photo upload endpoint.
// Native app clients POST the raw image bytes (body) with a suggested
// `path` query string, e.g. ?path=task_photos/<taskId>/proof_<ts>.jpg
// The file is saved under /public_html/uploads and a public URL returned.
// Web clients are NOT expected here (browsers block HTTP calls from the
// HTTPS web build); they fall back to inline base64 on the document.

// Allow larger uploads than the PHP defaults (raw-body POST is bounded by
// post_max_size; multipart by upload_max_filesize).
ini_set('upload_max_filesize', '15M');
ini_set('post_max_size', '16M');
ini_set('max_execution_time', '60');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-App-Secret');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
    exit;
}

// Only the app knows the shared secret. Without it, this endpoint is an
// anonymous 14 MB disk-fill hole.
tt_require_app_secret();

$bytes = file_get_contents('php://input');
if ($bytes === false || $bytes === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Empty request body']);
    exit;
}

if (strlen($bytes) > 14 * 1024 * 1024) {
    http_response_code(413);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Image too large (max 14 MB)']);
    exit;
}

// Detect real image type from magic bytes.
$ext = null;
$prefix = substr($bytes, 0, 12);
if (str_starts_with($bytes, "\xFF\xD8\xFF")) {
    $ext = 'jpg';
} elseif (str_starts_with($bytes, "\x89PNG\r\n\x1a\n")) {
    $ext = 'png';
} elseif (strlen($bytes) >= 12 && substr($bytes, 0, 4) === 'RIFF' && substr($bytes, 8, 4) === 'WEBP') {
    $ext = 'webp';
}

if ($ext === null) {
    http_response_code(415);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Only JPEG, PNG or WEBP images are allowed']);
    exit;
}

// Sanitize the suggested path into a safe relative path under /uploads.
$raw = (string) ($_GET['path'] ?? '');
$parts = [];
foreach (explode('/', $raw) as $seg) {
    $seg = preg_replace('/[^A-Za-z0-9._-]/', '', $seg);
    if ($seg === '' || $seg === '.' || $seg === '..') {
        continue;
    }
    $parts[] = $seg;
}
if ($parts === []) {
    $parts[] = 'misc';
}
$relPath = implode('/', $parts);
$relPath = preg_replace('/\.(jpe?g|png|webp)$/i', '', $relPath);
$relPath .= '.' . $ext;

$uploadsDir = __DIR__ . '/../../uploads';
$dest = $uploadsDir . '/' . $relPath;

// Safety: reject anything that could escape the uploads directory.
if (str_contains($relPath, '..') || str_starts_with($relPath, '/')) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Invalid path']);
    exit;
}

$subDir = dirname($dest);
if (!is_dir($subDir) && !@mkdir($subDir, 0755, true)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Uploads directory not writable']);
    exit;
}
if (!is_writable($subDir)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Uploads directory not writable']);
    exit;
}

$tmp = $dest . '.tmp' . getmypid();
if (@file_put_contents($tmp, $bytes) === false) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Could not save file']);
    exit;
}
if (!@rename($tmp, $dest)) {
    @unlink($tmp);
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Could not finalize file']);
    exit;
}

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'modali.powerpme.com';
// $relPath only contains [A-Za-z0-9._/-], so it is URL-safe as-is.
$url = $scheme . '://' . $host . '/uploads/' . $relPath;

header('Content-Type: application/json');
echo json_encode(['ok' => true, 'url' => $url]);
