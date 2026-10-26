<?php
declare(strict_types=1);

/**
 * Send C-Notes push notification & persist in database for recipient.
 * Include this action in deployed api_flutter/notifications.php.
 */

if (file_exists(__DIR__ . '/vendor/autoload.php')) {
    require_once __DIR__ . '/vendor/autoload.php';
} elseif (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    require_once __DIR__ . '/../vendor/autoload.php';
}

if (file_exists(__DIR__ . '/FcmV1Sender.php')) {
    require_once __DIR__ . '/FcmV1Sender.php';
} elseif (file_exists(__DIR__ . '/fcm/FcmV1Sender.php')) {
    require_once __DIR__ . '/fcm/FcmV1Sender.php';
}

function sendCNoteNotification(PDO $pdo, int $authenticatedUserId, array $input): array {
    $recipientId = filter_var(
        $input['recipient_user_id'] ?? $input['received_by'] ?? $input['to_member_id'] ?? null,
        FILTER_VALIDATE_INT
    );

    if ($authenticatedUserId <= 0) {
        $authenticatedUserId = (int)($input['user_id'] ?? $input['sender_user_id'] ?? $input['given_by'] ?? 0);
    }

    $cnoteId = filter_var($input['cnote_id'] ?? $input['id'] ?? null, FILTER_VALIDATE_INT) ?: 0;

    // Verify recipient from cnotes table if cnote_id is present
    if ($cnoteId > 0) {
        try {
            $stmt = $pdo->prepare(
                'SELECT id, given_by, received_by FROM cnotes WHERE id = :id LIMIT 1'
            );
            $stmt->execute(['id' => $cnoteId]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                if (!$recipientId) {
                    $recipientId = (int) $row['received_by'];
                }
                if ($authenticatedUserId <= 0) {
                    $authenticatedUserId = (int) $row['given_by'];
                }
            }
        } catch (Throwable $e) {}
    }

    if (!$recipientId || $recipientId < 1 || ($authenticatedUserId > 0 && $recipientId === $authenticatedUserId)) {
        throw new InvalidArgumentException('Valid recipient_user_id (different from sender) is required.');
    }

    // Look up sender's display name
    $senderName = trim((string)($input['sender_name'] ?? ''));
    if ($senderName === '' && $authenticatedUserId > 0) {
        try {
            $userStmt = $pdo->prepare('SELECT name, first_name FROM users WHERE id = :id LIMIT 1');
            $userStmt->execute(['id' => $authenticatedUserId]);
            $uRow = $userStmt->fetch(PDO::FETCH_ASSOC);
            if ($uRow) {
                $senderName = $uRow['name'] ?? $uRow['first_name'] ?? '';
            }
        } catch (Throwable $e) {}
    }

    $amount = trim((string)($input['amount'] ?? ''));
    $company = trim((string)($input['company'] ?? $input['company_name'] ?? ''));

    $amountStr = !empty($amount) ? " of Rs {$amount}" : '';
    $msgBody = !empty($senderName)
        ? "{$senderName} gave you a C-Note{$amountStr}."
        : "You received a new C-Note{$amountStr}.";
    if (!empty($company)) {
        $msgBody .= " ({$company})";
    }

    // Deduplication check via delivery table or recent notifications table
    if ($cnoteId > 0) {
        try {
            $claim = $pdo->prepare(
                'INSERT INTO cnote_notification_deliveries (cnote_id, recipient_user_id) VALUES (:cid, :uid)'
            );
            $claim->execute(['cid' => $cnoteId, 'uid' => $recipientId]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') {
                return ['success' => true, 'fcm_accepted' => true, 'duplicate' => true];
            }
            // If table does not exist or has another error, continue to ensure delivery
        }
    } else {
        // Only deduplicate within the last 15 seconds to prevent rapid double-taps
        try {
            $checkStmt = $pdo->prepare(
                'SELECT id FROM notifications WHERE (user_id = :uid OR member_id = :mid) AND type = "cnote" AND message = :msg AND created_at >= (NOW() - INTERVAL 15 SECOND) LIMIT 1'
            );
            $checkStmt->execute(['uid' => $recipientId, 'mid' => $recipientId, 'msg' => $msgBody]);
            if ($checkStmt->fetch()) {
                return ['success' => true, 'fcm_accepted' => true, 'duplicate' => true];
            }
        } catch (Throwable $e) {}
    }

    // Persist to notifications table for recipient
    try {
        $notification = $pdo->prepare(
            'INSERT INTO notifications (user_id, title, message, type, is_read, status, created_at)
             VALUES (:user_id, :title, :message, :type, 0, :status, NOW())'
        );
        $notification->execute([
            'user_id' => $recipientId,
            'title'   => 'New Business C-Note',
            'message' => $msgBody,
            'type'    => 'cnote',
            'status'  => 'unread',
        ]);
    } catch (Throwable $e) {
        try {
            $notification = $pdo->prepare(
                'INSERT INTO notifications (member_id, title, message, type, is_read, status, created_at)
                 VALUES (:member_id, :title, :message, :type, 0, :status, NOW())'
            );
            $notification->execute([
                'member_id' => $recipientId,
                'title'     => 'New Business C-Note',
                'message'   => $msgBody,
                'type'      => 'cnote',
                'status'    => 'unread',
            ]);
        } catch (Throwable $e2) {
            try {
                $notification = $pdo->prepare(
                    'INSERT INTO notifications (user_id, title, message, type, is_read)
                     VALUES (:user_id, :title, :message, :type, 0)'
                );
                $notification->execute([
                    'user_id' => $recipientId,
                    'title'   => 'New Business C-Note',
                    'message' => $msgBody,
                    'type'    => 'cnote',
                ]);
            } catch (Throwable $e3) {
                error_log('Failed to persist C-Note notification: ' . $e3->getMessage());
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
            'message' => 'Notification recorded, but member has no registered device token.',
        ];
    }

    $projectId = getenv('FIREBASE_PROJECT_ID') ?: 'rmb-connect-531eb';
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
            $messageNames[] = $sender->sendCNote(
                $token,
                $recipientId,
                $cnoteId,
                $senderName,
                $amount,
                $company
            )['name'];
        } catch (Throwable $tokenError) {
            if (str_contains($tokenError->getMessage(), 'UNREGISTERED') ||
                str_contains($tokenError->getMessage(), 'INVALID_ARGUMENT')) {
                $pdo->prepare('DELETE FROM device_tokens WHERE user_id = :user_id AND fcm_token = :fcm_token')
                    ->execute(['user_id' => $recipientId, 'fcm_token' => $token]);
                continue;
            }
            error_log('FCM C-Note push error: ' . $tokenError->getMessage());
        }
    }

    return [
        'success' => true,
        'fcm_accepted' => !empty($messageNames),
        'message_names' => $messageNames,
    ];
}

