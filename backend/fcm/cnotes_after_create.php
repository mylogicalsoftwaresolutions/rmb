<?php
declare(strict_types=1);

// Call this from the existing api_flutter/cnotes.php or api/cnotes.php after the INSERT
// has committed and $newCNoteId is known. Web and Mobile must both create
// C-Notes through that same endpoint/table. The delivery check in
// sendCNoteNotification prevents duplicate records even if the client calls
// notifications.php as well.

if (file_exists(__DIR__ . '/notifications_send_cnote.php')) {
    require_once __DIR__ . '/notifications_send_cnote.php';
} elseif (file_exists(__DIR__ . '/fcm/notifications_send_cnote.php')) {
    require_once __DIR__ . '/fcm/notifications_send_cnote.php';
}

function notifyCNoteRecipientAfterCreate(
    PDO $pdo,
    int $authenticatedUserId,
    int $newCNoteId,
    int $recipientUserId,
    string $amount = '',
    string $company = ''
): void {
    try {
        if (!function_exists('sendCNoteNotification')) {
            error_log('sendCNoteNotification function not found in notifyCNoteRecipientAfterCreate');
            return;
        }
        sendCNoteNotification($pdo, $authenticatedUserId, [
            'cnote_id' => $newCNoteId,
            'recipient_user_id' => $recipientUserId,
            'amount' => $amount,
            'company' => $company,
        ]);
    } catch (Throwable $error) {
        error_log(sprintf(
            'CNote push/notification failed: cnote_id=%d recipient_user_id=%d error=%s',
            $newCNoteId,
            $recipientUserId,
            $error->getMessage()
        ));
    }
}

