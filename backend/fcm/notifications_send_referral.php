<?php
declare(strict_types=1);

// Include this action in the deployed api_flutter/notifications.php after its
// existing PDO/session bootstrap. It requires $pdo (PDO) and $authenticatedUserId
// (the server-verified caller id). Do not use a client-supplied sender id as auth.
// Run `composer install --no-dev --optimize-autoloader` in this directory and
// set GOOGLE_APPLICATION_CREDENTIALS outside the web root.

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/FcmV1Sender.php';

function sendReferralNotification(PDO $pdo, int $authenticatedUserId, array $input): array {
    $referralId = filter_var($input['referral_id'] ?? null, FILTER_VALIDATE_INT);
    if (!$referralId || $referralId < 1) {
        throw new InvalidArgumentException('referral_id is required.');
    }

    // The referral row is the only source of the recipient. A Web/mobile
    // caller may provide recipient_user_id for validation, but it can never
    // choose an arbitrary FCM target.
    $referral = $pdo->prepare(
        'SELECT id, given_by, received_by FROM referrals WHERE id = :id LIMIT 1'
    );
    $referral->execute(['id' => $referralId]);
    $row = $referral->fetch(PDO::FETCH_ASSOC);
    if (!$row || (int) $row['given_by'] !== $authenticatedUserId) {
        throw new RuntimeException('Referral was not found for the signed-in user.');
    }
    $recipientId = (int) $row['received_by'];
    if ($recipientId < 1 || $recipientId === $authenticatedUserId) {
        throw new RuntimeException('A referral cannot notify its sender.');
    }
    if (isset($input['recipient_user_id']) && (int) $input['recipient_user_id'] !== $recipientId) {
        throw new RuntimeException('Selected receiving member does not match the referral.');
    }

    // Claim the delivery before contacting FCM. The unique key makes refresh,
    // retry, and a simultaneous Web/mobile request safe: only the first
    // request sends a push for a referral-recipient pair.
    try {
        $claim = $pdo->prepare(
            'INSERT INTO referral_notification_deliveries (referral_id, recipient_user_id) VALUES (:referral_id, :recipient_user_id)'
        );
        $claim->execute(['referral_id' => $referralId, 'recipient_user_id' => $recipientId]);
    } catch (PDOException $e) {
        if ($e->getCode() === '23000') {
            return ['success' => true, 'fcm_accepted' => true, 'duplicate' => true];
        }
        throw $e;
    }

    // A push notification alone is not visible in the app's Notifications
    // page. Persist the same event for the recipient before attempting FCM,
    // so it remains available even when their device is offline or Firebase
    // delivery is delayed. The delivery claim above keeps this one record per
    // referral/recipient pair.
    $notification = $pdo->prepare(
        'INSERT INTO notifications (user_id, title, message, type, is_read)
         VALUES (:user_id, :title, :message, :type, 0)'
    );
    $notification->execute([
        'user_id' => $recipientId,
        'title' => 'New Referral',
        'message' => 'You have received a new referral.',
        'type' => 'referral',
    ]);

    $statement = $pdo->prepare(
        'SELECT fcm_token FROM device_tokens WHERE user_id = :user_id ORDER BY updated_at DESC'
    );
    $statement->execute(['user_id' => $recipientId]);
    $tokens = $statement->fetchAll(PDO::FETCH_COLUMN);
    try {
        if (!$tokens) throw new RuntimeException('The receiving member has no registered device token.');
        $projectId = getenv('FIREBASE_PROJECT_ID');
        if (!$projectId) throw new RuntimeException('FIREBASE_PROJECT_ID is not configured.');
        $sender = new FcmV1Sender($projectId);
        $messageNames = [];
        $lastError = null;
        foreach (array_unique($tokens) as $token) {
            try {
                $messageNames[] =
                    $sender->sendReferral($token, $recipientId, $referralId)['name'];
            } catch (Throwable $tokenError) {
                $lastError = $tokenError;
                // A stale token belongs to this one device, not necessarily
                // every device signed into the receiving member's account.
                // Remove only that token and continue with the remaining
                // registered devices.
                if (str_contains($tokenError->getMessage(), 'UNREGISTERED') ||
                    str_contains($tokenError->getMessage(), 'INVALID_ARGUMENT')) {
                    $pdo->prepare('DELETE FROM device_tokens WHERE user_id = :user_id AND fcm_token = :fcm_token')
                        ->execute(['user_id' => $recipientId, 'fcm_token' => $token]);
                    continue;
                }
                throw $tokenError;
            }
        }
        if (!$messageNames) {
            throw new RuntimeException(
                'Firebase did not accept a notification for any registered device.' .
                ($lastError ? ' ' . $lastError->getMessage() : '')
            );
        }
        $pdo->prepare(
            'UPDATE referral_notification_deliveries SET fcm_message_names = :messages WHERE referral_id = :referral_id AND recipient_user_id = :recipient_user_id'
        )->execute([
            'messages' => json_encode($messageNames, JSON_THROW_ON_ERROR),
            'referral_id' => $referralId,
            'recipient_user_id' => $recipientId,
        ]);
    } catch (Throwable $e) {
        // Do not permanently mark a failed delivery as sent; a deliberate
        // retry can claim it again. Individual stale tokens are removed in
        // the loop above without affecting another of the recipient's devices.
        $pdo->prepare(
            'DELETE FROM referral_notification_deliveries WHERE referral_id = :referral_id AND recipient_user_id = :recipient_user_id'
        )->execute(['referral_id' => $referralId, 'recipient_user_id' => $recipientId]);
        throw $e;
    }

    return ['success' => true, 'fcm_accepted' => true, 'message_names' => $messageNames];
}

// In notifications.php's POST action router:
// if (($_POST['action'] ?? '') === 'send_referral') {
//     $result = sendReferralNotification($pdo, $authenticatedUserId, $_POST);
//     http_response_code(200);
//     header('Content-Type: application/json');
//     echo json_encode($result);
//     exit;
// }
