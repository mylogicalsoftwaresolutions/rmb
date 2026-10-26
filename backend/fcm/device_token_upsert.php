<?php
declare(strict_types=1);

// Include this action in deployed api_flutter/device_token.php after its
// existing PDO/session bootstrap. $authenticatedUserId must be determined by
// server-side authentication, not trusted from $_POST['user_id'] alone.

function upsertDeviceToken(PDO $pdo, int $authenticatedUserId, array $input): array {
    $token = trim((string) ($input['fcm_token'] ?? ''));
    $platform = strtolower(trim((string) ($input['platform'] ?? 'android')));
    if ($token === '' || strlen($token) > 512) {
        throw new InvalidArgumentException('A valid fcm_token is required.');
    }
    if (!in_array($platform, ['android', 'ios', 'web'], true)) {
        throw new InvalidArgumentException('Unsupported token platform.');
    }

    $statement = $pdo->prepare(
        'INSERT INTO device_tokens (user_id, fcm_token, platform)
         VALUES (:user_id, :fcm_token, :platform)
         ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform), updated_at = CURRENT_TIMESTAMP'
    );
    $statement->execute([
        'user_id' => $authenticatedUserId,
        'fcm_token' => $token,
        'platform' => $platform,
    ]);
    return ['success' => true, 'token_registered' => true];
}
