<?php
declare(strict_types=1);

/**
 * Add this router block into your deployed `api_flutter/notifications.php` (and `api/notifications.php`)
 * to handle push notifications for Referral, R2R, C-Notes, and Testimonials across Web and Mobile.
 * 
 * Required includes:
 *   require_once __DIR__ . '/fcm/notifications_send_referral.php';
 *   require_once __DIR__ . '/fcm/notifications_send_r2r.php';
 *   require_once __DIR__ . '/fcm/notifications_send_cnote.php';
 *   require_once __DIR__ . '/fcm/notifications_send_testimonial.php';
 */

$action = strtolower(trim((string)($_POST['action'] ?? $_GET['action'] ?? '')));

// 1. Referral push notification
if ($action === 'send_referral') {
    require_once __DIR__ . '/notifications_send_referral.php';
    try {
        $result = sendReferralNotification($pdo, $authenticatedUserId, $_POST);
        http_response_code(200);
        header('Content-Type: application/json');
        echo json_encode($result);
    } catch (Throwable $e) {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit;
}

// 2. R2R Meeting push notification
if ($action === 'send_r2r') {
    require_once __DIR__ . '/notifications_send_r2r.php';
    try {
        $result = sendR2RNotification($pdo, $authenticatedUserId, $_POST);
        http_response_code(200);
        header('Content-Type: application/json');
        echo json_encode($result);
    } catch (Throwable $e) {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit;
}

// 3. C-Note push notification
if ($action === 'send_cnote') {
    if (file_exists(__DIR__ . '/notifications_send_cnote.php')) {
        require_once __DIR__ . '/notifications_send_cnote.php';
    } elseif (file_exists(__DIR__ . '/fcm/notifications_send_cnote.php')) {
        require_once __DIR__ . '/fcm/notifications_send_cnote.php';
    }
    try {
        $authId = (int)($authenticatedUserId ?? $_POST['user_id'] ?? $_GET['user_id'] ?? 0);
        $result = sendCNoteNotification($pdo, $authId, $_POST);
        http_response_code(200);
        header('Content-Type: application/json');
        echo json_encode($result);
    } catch (Throwable $e) {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit;
}

// 4. Testimonial push notification
if ($action === 'send_testimonial') {
    require_once __DIR__ . '/notifications_send_testimonial.php';
    try {
        $result = sendTestimonialNotification($pdo, $authenticatedUserId, $_POST);
        http_response_code(200);
        header('Content-Type: application/json');
        echo json_encode($result);
    } catch (Throwable $e) {
        http_response_code(400);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
    exit;
}
