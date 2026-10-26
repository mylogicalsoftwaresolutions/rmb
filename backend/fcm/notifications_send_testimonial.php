<?php
declare(strict_types=1);

/**
 * Send Testimonial push notification & persist in database for recipient.
 * Include this action in deployed api_flutter/notifications.php.
 */

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/FcmV1Sender.php';

function sendTestimonialNotification(PDO $pdo, int $authenticatedUserId, array $input): array {
    $recipientId = filter_var(
        $input['recipient_user_id'] ?? $input['received_by'] ?? $input['to_member_id'] ?? null,
        FILTER_VALIDATE_INT
    );

    $testimonialId = filter_var($input['testimonial_id'] ?? $input['id'] ?? null, FILTER_VALIDATE_INT) ?: 0;

    // Verify recipient from testimonials table if testimonial_id is present
    if ($testimonialId > 0) {
        try {
            $stmt = $pdo->prepare(
                'SELECT id, given_by, received_by FROM testimonials WHERE id = :id LIMIT 1'
            );
            $stmt->execute(['id' => $testimonialId]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row && !$recipientId) {
                $recipientId = (int) $row['received_by'];
            }
        } catch (Throwable $e) {}
    }

    if (!$recipientId || $recipientId < 1 || $recipientId === $authenticatedUserId) {
        throw new InvalidArgumentException('Valid recipient_user_id (different from sender) is required.');
    }

    // Look up sender's display name
    $senderName = trim((string)($input['sender_name'] ?? ''));
    if ($senderName === '') {
        try {
            $userStmt = $pdo->prepare('SELECT name, first_name, display_name FROM users WHERE id = :id LIMIT 1');
            $userStmt->execute(['id' => $authenticatedUserId]);
            $uRow = $userStmt->fetch(PDO::FETCH_ASSOC);
            if ($uRow) {
                $senderName = $uRow['display_name'] ?? $uRow['name'] ?? $uRow['first_name'] ?? '';
            }
        } catch (Throwable $e) {}
    }

    $title = trim((string)($input['title'] ?? ''));
    $msgBody = !empty($senderName)
        ? "{$senderName} gave you a testimonial" . (!empty($title) ? ": \"{$title}\"" : ".")
        : "You have received a new testimonial" . (!empty($title) ? ": \"{$title}\"" : ".");

    // Deduplication check via delivery table or notifications table
    if ($testimonialId > 0) {
        try {
            $claim = $pdo->prepare(
                'INSERT INTO testimonial_notification_deliveries (testimonial_id, recipient_user_id) VALUES (:tid, :uid)'
            );
            $claim->execute(['tid' => $testimonialId, 'uid' => $recipientId]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') {
                return ['success' => true, 'fcm_accepted' => true, 'duplicate' => true];
            }
        }
    } else {
        try {
            $checkStmt = $pdo->prepare(
                'SELECT id FROM notifications WHERE (user_id = :uid OR member_id = :mid) AND type = "testimonial" AND message = :msg LIMIT 1'
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
            'title'   => 'New Testimonial',
            'message' => $msgBody,
            'type'    => 'testimonial',
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
                'title'     => 'New Testimonial',
                'message'   => $msgBody,
                'type'      => 'testimonial',
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
                    'title'   => 'New Testimonial',
                    'message' => $msgBody,
                    'type'    => 'testimonial',
                ]);
            } catch (Throwable $e3) {
                error_log('Failed to persist testimonial notification: ' . $e3->getMessage());
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
            $messageNames[] = $sender->sendTestimonial(
                $token,
                $recipientId,
                $testimonialId,
                $senderName,
                $title
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
