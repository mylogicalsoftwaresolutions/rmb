<?php
declare(strict_types=1);

// Include this action in the deployed api_flutter/notifications.php after its
// existing PDO/session bootstrap. It requires $pdo (PDO) and $authenticatedUserId
// (the server-verified caller id). Do not use a client-supplied sender id as auth.
// Run `composer install --no-dev --optimize-autoloader` in this directory and
// set GOOGLE_APPLICATION_CREDENTIALS outside the web root.

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/FcmV1Sender.php';

function sendR2RNotification(PDO $pdo, int $authenticatedUserId, array $input): array {
    $recipientId = filter_var(
        $input['recipient_user_id'] ?? $input['partner_user_id'] ?? null,
        FILTER_VALIDATE_INT
    );

    $r2rId = filter_var($input['r2r_id'] ?? null, FILTER_VALIDATE_INT) ?: 0;

    // If an r2r_id was provided, verify it exists in the r2r table if table is present
    if ($r2rId > 0) {
        try {
            $stmt = $pdo->prepare(
                'SELECT id, member_id, partner_id FROM r2r WHERE id = :id LIMIT 1'
            );
            $stmt->execute(['id' => $r2rId]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                // Determine recipient from record if not supplied
                if (!$recipientId) {
                    $recipientId = ((int) $row['member_id'] === $authenticatedUserId)
                        ? (int) $row['partner_id']
                        : (int) $row['member_id'];
                }
            }
        } catch (Throwable $e) {
            // Table might have different columns or structure, fall back to supplied recipient
        }
    }

    if (!$recipientId || $recipientId < 1 || $recipientId === $authenticatedUserId) {
        throw new InvalidArgumentException('Valid recipient_user_id (different from sender) is required.');
    }

    // Look up sender's display name
    $senderName = '';
    try {
        $userStmt = $pdo->prepare('SELECT name, first_name FROM users WHERE id = :id LIMIT 1');
        $userStmt->execute(['id' => $authenticatedUserId]);
        $uRow = $userStmt->fetch(PDO::FETCH_ASSOC);
        if ($uRow) {
            $senderName = $uRow['name'] ?? $uRow['first_name'] ?? '';
        }
    } catch (Throwable $e) {}

    $date = filter_var($input['date'] ?? '', FILTER_DEFAULT);
    $location = filter_var($input['location'] ?? '', FILTER_DEFAULT);

    $msgBody = !empty($senderName)
        ? "{$senderName} has logged an R2R meeting with you."
        : "A new R2R meeting has been logged with you.";

    if (!empty($date)) {
        $msgBody .= " Date: {$date}.";
    }

    // Check if this R2R notification was already recorded to prevent duplicates
    try {
        $checkStmt = $pdo->prepare(
            'SELECT id FROM notifications WHERE (user_id = :uid OR member_id = :mid) AND type = "r2r" AND message = :msg LIMIT 1'
        );
        $checkStmt->execute(['uid' => $recipientId, 'mid' => $recipientId, 'msg' => $msgBody]);
        if ($checkStmt->fetch()) {
            return [
                'success' => true,
                'fcm_accepted' => true,
                'duplicate' => true,
                'message' => 'Notification already recorded.',
            ];
        }
    } catch (Throwable $e) {}

    // Persist to notifications table for recipient
    $inserted = false;
    try {
        $notification = $pdo->prepare(
            'INSERT INTO notifications (user_id, title, message, type, is_read, status, created_at)
             VALUES (:user_id, :title, :message, :type, 0, :status, NOW())'
        );
        $notification->execute([
            'user_id' => $recipientId,
            'title' => 'New R2R Meeting',
            'message' => $msgBody,
            'type' => 'r2r',
            'status' => 'unread',
        ]);
        $inserted = true;
    } catch (Throwable $e) {
        // Fallback if schema uses member_id
        try {
            $notification = $pdo->prepare(
                'INSERT INTO notifications (member_id, title, message, type, is_read, status, created_at)
                 VALUES (:member_id, :title, :message, :type, 0, :status, NOW())'
            );
            $notification->execute([
                'member_id' => $recipientId,
                'title' => 'New R2R Meeting',
                'message' => $msgBody,
                'type' => 'r2r',
                'status' => 'unread',
            ]);
            $inserted = true;
        } catch (Throwable $e2) {
            try {
                $notification = $pdo->prepare(
                    'INSERT INTO notifications (user_id, title, message, type, is_read)
                     VALUES (:user_id, :title, :message, :type, 0)'
                );
                $notification->execute([
                    'user_id' => $recipientId,
                    'title' => 'New R2R Meeting',
                    'message' => $msgBody,
                    'type' => 'r2r',
                ]);
                $inserted = true;
            } catch (Throwable $e3) {
                error_log('Failed to persist R2R notification: ' . $e3->getMessage());
            }
        }
    }

    // Look up FCM device tokens for recipient
    $statement = $pdo->prepare(
        'SELECT fcm_token FROM device_tokens WHERE user_id = :user_id ORDER BY updated_at DESC'
    );
    $statement->execute(['user_id' => $recipientId]);
    $tokens = $statement->fetchAll(PDO::FETCH_COLUMN);

    if (!$tokens) {
        return [
            'success' => true,
            'fcm_accepted' => false,
            'message' => 'Notification recorded, but partner has no registered device token.',
        ];
    }

    $projectId = getenv('FIREBASE_PROJECT_ID');
    if (!$projectId) {
        return [
            'success' => true,
            'fcm_accepted' => false,
            'message' => 'Notification recorded. FIREBASE_PROJECT_ID is not configured.',
        ];
    }

    $sender = new FcmV1Sender($projectId);
    $messageNames = [];
    foreach (array_unique($tokens) as $token) {
        try {
            $messageNames[] = $sender->sendR2R(
                $token,
                $recipientId,
                $r2rId,
                $senderName,
                $date,
                $location
            )['name'];
        } catch (Throwable $tokenError) {
            if (str_contains($tokenError->getMessage(), 'UNREGISTERED') ||
                str_contains($tokenError->getMessage(), 'INVALID_ARGUMENT')) {
                $pdo->prepare('DELETE FROM device_tokens WHERE user_id = :user_id AND fcm_token = :fcm_token')
                    ->execute(['user_id' => $recipientId, 'fcm_token' => $token]);
                continue;
            }
        }
    }

    return [
        'success' => true,
        'fcm_accepted' => !empty($messageNames),
        'message_names' => $messageNames,
    ];
}

// In notifications.php's POST action router:
// if (($_POST['action'] ?? '') === 'send_r2r') {
//     $result = sendR2RNotification($pdo, $authenticatedUserId, $_POST);
//     http_response_code(200);
//     header('Content-Type: application/json');
//     echo json_encode($result);
//     exit;
// }

