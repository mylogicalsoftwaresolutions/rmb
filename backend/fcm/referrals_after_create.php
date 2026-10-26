<?php
declare(strict_types=1);

// Call this from the existing api_flutter/referrals.php only after the INSERT
// has committed and $newReferralId is known. Web and Flutter must both create
// referrals through that same endpoint/table. The delivery table's unique key
// makes this safe even if the Flutter fallback calls notifications.php too.

require_once __DIR__ . '/notifications_send_referral.php';

function notifyReferralRecipientAfterCreate(
    PDO $pdo,
    int $authenticatedUserId,
    int $newReferralId,
    int $recipientUserId,
): void {
    try {
        sendReferralNotification($pdo, $authenticatedUserId, [
            'referral_id' => $newReferralId,
            'recipient_user_id' => $recipientUserId,
        ]);
    } catch (Throwable $error) {
        // Saving the referral remains successful. Log enough information for
        // operations to fix FCM/token errors without asking a member to retry
        // and create a duplicate referral.
        error_log(sprintf(
            'Referral push failed: referral_id=%d recipient_user_id=%d error=%s',
            $newReferralId,
            $recipientUserId,
            $error->getMessage(),
        ));
    }
}
