<?php

// Photo upload endpoint.
// Native app clients POST raw image bytes (body) with a `path` query string,
// e.g. ?path=task_photos/<taskId>/proof_<ts>.jpg
//
// Two modes:
//  1) Chunked (used by the app for smooth progress + retries): add
//     &chunk=N&total=M&totalBytes=X. Each request carries one slice of the
//     image, written to $dest.partN (overwrite, so retried chunks are
//     idempotent). The request where chunk == total stitches all parts in
//     order, validates the total size and the image magic bytes, then
//     publishes the file under $dest and returns the public URL.
//  2) Legacy whole-body POST: no chunk param; single-shot write (unchanged).
//
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
header('Access-Control-Allow-Headers: Content-Type');

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

$bytes = file_get_contents('php://input');
if ($bytes === false || $bytes === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Empty request body']);
    exit;
}

$isChunked = array_key_exists('chunk', $_GET);
$chunkNum = max(1, (int) ($_GET['chunk'] ?? 1));
$totalChunks = max(1, (int) ($_GET['total'] ?? 1));
$totalBytes = (int) ($_GET['totalBytes'] ?? 0);
if ($chunkNum > $totalChunks) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Invalid chunk number']);
    exit;
}

if (!$isChunked) {
    if (strlen($bytes) > 14 * 1024 * 1024) {
        http_response_code(413);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'Image too large (max 14 MB)']);
        exit;
    }
} else {
    if ($totalBytes <= 0 || $totalBytes > 14 * 1024 * 1024) {
        http_response_code(413);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'Image too large (max 14 MB)']);
        exit;
    }
    if (strlen($bytes) > 1024 * 1024) {
        http_response_code(413);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'Chunk too large (max 1 MB)']);
        exit;
    }
}

// Detect a real image type from magic bytes. Returns the file extension or
// null when the payload is not a supported image.
function detect_image_ext(string $prefix): ?string {
    if (str_starts_with($prefix, "\xFF\xD8\xFF")) {
        return 'jpg';
    }
    if (str_starts_with($prefix, "\x89PNG\r\n\x1a\n")) {
        return 'png';
    }
    if (strlen($prefix) >= 12 && substr($prefix, 0, 4) === 'RIFF' && substr($prefix, 8, 4) === 'WEBP') {
        return 'webp';
    }
    return null;
}

// Sanitize the suggested path into a safe relative path under /uploads
// (no extension yet: legacy mode detects it from the body, chunked mode from
// the stitched file).
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
$relBase = implode('/', $parts);
$relBase = preg_replace('/\.(jpe?g|png|webp)$/i', '', $relBase);

// Safety: reject anything that could escape the uploads directory.
if (str_contains($relBase, '..') || str_starts_with($relBase, '/')) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Invalid path']);
    exit;
}

$uploadsDir = __DIR__ . '/../../uploads';
$subDir = $uploadsDir . '/' . dirname($relBase);
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

$json = function (array $payload) {
    header('Content-Type: application/json');
    echo json_encode($payload);
};

// ─── Legacy whole-body mode ───────────────────────────────────────────────

if (!$isChunked) {
    $ext = detect_image_ext(substr($bytes, 0, 12));
    if ($ext === null) {
        http_response_code(415);
        $json(['ok' => false, 'error' => 'Only JPEG, PNG or WEBP images are allowed']);
        exit;
    }
    $dest = $uploadsDir . '/' . $relBase . '.' . $ext;

    $tmp = $dest . '.tmp' . getmypid();
    if (@file_put_contents($tmp, $bytes) === false) {
        http_response_code(500);
        $json(['ok' => false, 'error' => 'Could not save file']);
        exit;
    }
    if (!@rename($tmp, $dest)) {
        @unlink($tmp);
        http_response_code(500);
        $json(['ok' => false, 'error' => 'Could not finalize file']);
        exit;
    }

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'modali.powerpme.com';
    $url = $scheme . '://' . $host . '/uploads/' . $relBase . '.' . $ext;
    $json(['ok' => true, 'url' => $url]);
    exit;
}

// ─── Chunked mode ─────────────────────────────────────────────────────────

$partFile = $uploadsDir . '/' . $relBase . '.part' . $chunkNum;
if (@file_put_contents($partFile, $bytes) === false) {
    http_response_code(500);
    $json(['ok' => false, 'error' => 'Could not save chunk']);
    exit;
}

// Cumulative bytes received so far (server-authoritative progress).
$received = 0;
for ($i = 1; $i <= $chunkNum; $i++) {
    $p = $uploadsDir . '/' . $relBase . '.part' . $i;
    if (is_file($p)) {
        $received += filesize($p);
    }
}

if ($chunkNum < $totalChunks) {
    $json(['ok' => true, 'received' => $received]);
    exit;
}

// Last chunk: stitch all parts in order into a temporary file.
$stitch = $uploadsDir . '/' . $relBase . '.tmp' . getmypid();
$fh = @fopen($stitch, 'wb');
if (!$fh) {
    http_response_code(500);
    $json(['ok' => false, 'error' => 'Could not create final file']);
    exit;
}
$ok = true;
for ($i = 1; $i <= $totalChunks; $i++) {
    $p = $uploadsDir . '/' . $relBase . '.part' . $i;
    if (!is_file($p)) {
        $ok = false;
        break;
    }
    $h = @fopen($p, 'rb');
    if (!$h) {
        $ok = false;
        break;
    }
    stream_copy_to_stream($h, $fh);
    fclose($h);
}
fclose($fh);

if (!$ok) {
    @unlink($stitch);
    http_response_code(500);
    $json(['ok' => false, 'error' => 'Missing upload chunk, please retry']);
    exit;
}

if (filesize($stitch) !== $totalBytes) {
    @unlink($stitch);
    http_response_code(400);
    $json(['ok' => false, 'error' => 'Upload size mismatch, please retry']);
    exit;
}

$prefix = (string) @file_get_contents($stitch, false, null, 0, 12);
$ext = detect_image_ext($prefix);
if ($ext === null) {
    @unlink($stitch);
    http_response_code(415);
    $json(['ok' => false, 'error' => 'Only JPEG, PNG or WEBP images are allowed']);
    exit;
}

$dest = $uploadsDir . '/' . $relBase . '.' . $ext;
if (!@rename($stitch, $dest)) {
    @unlink($stitch);
    http_response_code(500);
    $json(['ok' => false, 'error' => 'Could not finalize file']);
    exit;
}

// Clean up the consumed parts.
for ($i = 1; $i <= $totalChunks; $i++) {
    @unlink($uploadsDir . '/' . $relBase . '.part' . $i);
}

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'modali.powerpme.com';
// $relBase only contains [A-Za-z0-9._/-], so it is URL-safe as-is.
$url = $scheme . '://' . $host . '/uploads/' . $relBase . '.' . $ext;

$json(['ok' => true, 'url' => $url]);
