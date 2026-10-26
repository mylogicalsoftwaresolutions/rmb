<?php
declare(strict_types=1);

use Google\Client;

final class FcmV1Sender {
    public function __construct(private string $projectId) {}

    private function getAccessToken(): string {
        $credentials = getenv('GOOGLE_APPLICATION_CREDENTIALS');
        if ($credentials === false || $credentials === '' || !is_readable($credentials)) {
            throw new RuntimeException('FCM service-account credentials are not configured.');
        }

        // Cache the access token locally to prevent 2-4 second OAuth latency on every push
        $cacheFile = sys_get_temp_dir() . '/fcm_access_token_' . md5((string) $credentials) . '.json';
        if (is_file($cacheFile)) {
            $cached = @json_decode((string) @file_get_contents($cacheFile), true);
            if (is_array($cached) && !empty($cached['token']) && !empty($cached['expires_at'])) {
                // If token is valid for at least 5 more minutes, use it immediately
                if ($cached['expires_at'] > (time() + 300)) {
                    return (string) $cached['token'];
                }
            }
        }

        $client = new Client();
        $client->setAuthConfig($credentials);
        $client->addScope('https://www.googleapis.com/auth/firebase.messaging');
        $authResponse = $client->fetchAccessTokenWithAssertion();
        $accessToken = $authResponse['access_token'] ?? null;
        $expiresIn = (int) ($authResponse['expires_in'] ?? 3600);
        if (!$accessToken) {
            throw new RuntimeException('Could not obtain an FCM OAuth token.');
        }

        // Save token to cache
        @file_put_contents($cacheFile, json_encode([
            'token' => $accessToken,
            'expires_at' => time() + $expiresIn,
        ]));

        return $accessToken;
    }

    private function sendPayload(array $message): array {
        $accessToken = $this->getAccessToken();
        $payload = json_encode(['message' => $message], JSON_THROW_ON_ERROR);

        $curl = curl_init("https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send");
        curl_setopt_array($curl, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 15,
        ]);
        $body = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $error = curl_error($curl);
        curl_close($curl);
        if ($body === false) {
            throw new RuntimeException('FCM request failed: ' . $error);
        }

        $decoded = json_decode($body, true);
        if ($status < 200 || $status >= 300 || !is_array($decoded) || empty($decoded['name'])) {
            throw new RuntimeException('FCM rejected notification: ' . $body);
        }
        return $decoded;
    }

    /**
     * Send Referral push notification (Mobile + Web)
     */
    public function sendReferral(string $token, int $recipientUserId, int $referralId, string $senderName = ''): array {
        $title = 'New Referral';
        $bodyText = !empty($senderName)
            ? "{$senderName} gave you a new referral."
            : 'You have received a new referral.';

        return $this->sendPayload([
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $bodyText,
            ],
            'data' => [
                'type' => 'referral',
                'referral_id' => (string) $referralId,
                'recipient_user_id' => (string) $recipientUserId,
                'title' => $title,
                'message' => $bodyText,
            ],
            'android' => [
                'priority' => 'high',
                'direct_boot_ok' => true,
                'ttl' => '86400s',
                'notification' => [
                    'channel_id' => 'rmb_connect_alerts_v2',
                    'visibility' => 'PUBLIC',
                    'notification_priority' => 'PRIORITY_MAX',
                    'sound' => 'volvo3',
                    'default_vibrate_timings' => true,
                ],
            ],
            'apns' => [
                'headers' => ['apns-priority' => '10'],
                'payload' => ['aps' => ['sound' => 'volvo3.mp3', 'badge' => 1, 'content-available' => 1]],
            ],
            'webpush' => [
                'headers' => ['Urgency' => 'high'],
                'notification' => [
                    'title' => $title,
                    'body' => $bodyText,
                    'icon' => '/icons/Icon-192.png',
                    'badge' => '/icons/Icon-192.png',
                ],
                'fcm_options' => ['link' => '/'],
            ],
        ]);
    }

    /**
     * Send R2R Meeting push notification (Mobile + Web)
     */
    public function sendR2R(string $token, int $recipientUserId, int $r2rId, string $senderName = '', string $date = '', string $location = ''): array {
        $title = 'New R2R Meeting';
        $bodyText = !empty($senderName)
            ? "{$senderName} has logged an R2R meeting with you."
            : "A new R2R meeting has been logged with you.";

        return $this->sendPayload([
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $bodyText,
            ],
            'data' => [
                'type' => 'r2r',
                'r2r_id' => (string) $r2rId,
                'recipient_user_id' => (string) $recipientUserId,
                'date' => $date,
                'location' => $location,
                'title' => $title,
                'message' => $bodyText,
            ],
            'android' => [
                'priority' => 'high',
                'direct_boot_ok' => true,
                'ttl' => '86400s',
                'notification' => [
                    'channel_id' => 'rmb_connect_alerts_v2',
                    'visibility' => 'PUBLIC',
                    'notification_priority' => 'PRIORITY_MAX',
                    'sound' => 'volvo3',
                    'default_vibrate_timings' => true,
                ],
            ],
            'apns' => [
                'headers' => ['apns-priority' => '10'],
                'payload' => ['aps' => ['sound' => 'volvo3.mp3', 'badge' => 1, 'content-available' => 1]],
            ],
            'webpush' => [
                'headers' => ['Urgency' => 'high'],
                'notification' => [
                    'title' => $title,
                    'body' => $bodyText,
                    'icon' => '/icons/Icon-192.png',
                    'badge' => '/icons/Icon-192.png',
                ],
                'fcm_options' => ['link' => '/'],
            ],
        ]);
    }

    /**
     * Send C-Note push notification (Mobile + Web)
     */
    public function sendCNote(string $token, int $recipientUserId, int $cnoteId, string $senderName = '', string $amount = '', string $company = ''): array {
        $title = 'New Business C-Note';
        $amountStr = !empty($amount) ? " of Rs {$amount}" : '';
        $bodyText = !empty($senderName)
            ? "{$senderName} gave you a C-Note{$amountStr}."
            : "You received a new C-Note{$amountStr}.";

        return $this->sendPayload([
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $bodyText,
            ],
            'data' => [
                'type' => 'cnote',
                'cnote_id' => (string) $cnoteId,
                'recipient_user_id' => (string) $recipientUserId,
                'amount' => $amount,
                'company' => $company,
                'title' => $title,
                'message' => $bodyText,
            ],
            'android' => [
                'priority' => 'high',
                'direct_boot_ok' => true,
                'ttl' => '86400s',
                'notification' => [
                    'channel_id' => 'rmb_connect_alerts_v2',
                    'visibility' => 'PUBLIC',
                    'notification_priority' => 'PRIORITY_MAX',
                    'sound' => 'volvo3',
                    'default_vibrate_timings' => true,
                ],
            ],
            'apns' => [
                'headers' => ['apns-priority' => '10'],
                'payload' => ['aps' => ['sound' => 'volvo3.mp3', 'badge' => 1, 'content-available' => 1]],
            ],
            'webpush' => [
                'headers' => ['Urgency' => 'high'],
                'notification' => [
                    'title' => $title,
                    'body' => $bodyText,
                    'icon' => '/icons/Icon-192.png',
                    'badge' => '/icons/Icon-192.png',
                ],
                'fcm_options' => ['link' => '/'],
            ],
        ]);
    }

    /**
     * Send Testimonial push notification (Mobile + Web)
     */
    public function sendTestimonial(string $token, int $recipientUserId, int $testimonialId, string $senderName = '', string $testimonialTitle = ''): array {
        $title = 'New Testimonial';
        $bodyText = !empty($senderName)
            ? "{$senderName} gave you a testimonial" . (!empty($testimonialTitle) ? ": \"{$testimonialTitle}\"" : ".")
            : "You have received a new testimonial" . (!empty($testimonialTitle) ? ": \"{$testimonialTitle}\"" : ".");

        return $this->sendPayload([
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $bodyText,
            ],
            'data' => [
                'type' => 'testimonial',
                'testimonial_id' => (string) $testimonialId,
                'recipient_user_id' => (string) $recipientUserId,
                'title' => $title,
                'message' => $bodyText,
            ],
            'android' => [
                'priority' => 'high',
                'direct_boot_ok' => true,
                'ttl' => '86400s',
                'notification' => [
                    'channel_id' => 'rmb_connect_alerts_v2',
                    'visibility' => 'PUBLIC',
                    'notification_priority' => 'PRIORITY_MAX',
                    'sound' => 'volvo3',
                    'default_vibrate_timings' => true,
                ],
            ],
            'apns' => [
                'headers' => ['apns-priority' => '10'],
                'payload' => ['aps' => ['sound' => 'volvo3.mp3', 'badge' => 1, 'content-available' => 1]],
            ],
            'webpush' => [
                'headers' => ['Urgency' => 'high'],
                'notification' => [
                    'title' => $title,
                    'body' => $bodyText,
                    'icon' => '/icons/Icon-192.png',
                    'badge' => '/icons/Icon-192.png',
                ],
                'fcm_options' => ['link' => '/'],
            ],
        ]);
    }
}
