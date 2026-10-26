<?php
declare(strict_types=1);

// Call this from the existing api_flutter/r2r.php or api/r2r.php after the INSERT
// has committed and $newR2RId is known. Web and Mobile must both create
// R2R meetings through that same endpoint/table. The delivery check in
// sendR2RNotification prevents duplicate records even if the client calls
// notifications.php as well.

require_once __DIR__ . '/notifications_send_r2r.php';

function notifyR2RRecipientAfterCreate(
    PDO $pdo,
    int $authenticatedUserId,
    int $newR2RId,
    int $partnerUserId,
    string $date = '',
    string $location = '',
    string $topic = ''
): void {
    try {
        sendR2RNotification($pdo, $authenticatedUserId, [
            'r2r_id' => $newR2RId,
            'recipient_user_id' => $partnerUserId,
            'partner_user_id' => $partnerUserId,
            'date' => $date,
            'location' => $location,
            'topic' => $topic,
        ]);
    } catch (Throwable $error) {
        // Saving the R2R meeting remains successful. Log enough information for
        // operations to diagnose issues without blocking the member or duplicating the record.
        error_log(sprintf(
            'R2R push/notification failed: r2r_id=%d partner_user_id=%d error=%s',
            $newR2RId,
            $partnerUserId,
            $error->getMessage()
        ));
    }
}
