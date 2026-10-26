<?php
declare(strict_types=1);

// Call this from the existing api_flutter/testimonials.php or api/testimonials.php after the INSERT
// has committed and $newTestimonialId is known. Web and Mobile must both create
// Testimonials through that same endpoint/table. The delivery check in
// sendTestimonialNotification prevents duplicate records even if the client calls
// notifications.php as well.

require_once __DIR__ . '/notifications_send_testimonial.php';

function notifyTestimonialRecipientAfterCreate(
    PDO $pdo,
    int $authenticatedUserId,
    int $newTestimonialId,
    int $recipientUserId,
    string $title = '',
    string $content = ''
): void {
    try {
        sendTestimonialNotification($pdo, $authenticatedUserId, [
            'testimonial_id' => $newTestimonialId,
            'recipient_user_id' => $recipientUserId,
            'title' => $title,
            'content' => $content,
        ]);
    } catch (Throwable $error) {
        error_log(sprintf(
            'Testimonial push/notification failed: testimonial_id=%d recipient_user_id=%d error=%s',
            $newTestimonialId,
            $recipientUserId,
            $error->getMessage()
        ));
    }
}
