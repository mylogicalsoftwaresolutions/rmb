<?php
declare(strict_types=1);

/**
 * Add this code block into `api_flutter/dashboard.php` (and `api/dashboard.php`)
 * right where the `$data` response array is constructed for members.
 * 
 * It adds:
 *  - 'birthdays': list of active members celebrating their birthday today (Asia/Kolkata timezone)
 *  - 'today_birthdays': alias for 'birthdays'
 *  - 'anniversaries': list of active members celebrating their wedding anniversary today (Asia/Kolkata timezone)
 *  - 'today_anniversaries': alias for 'anniversaries'
 *  - 'upcoming_events': list of events scheduled on or after today (Asia/Kolkata timezone)
 *  - 'upcoming_meeting': next upcoming meeting if not already set
 */

// 0. Enforce local timezone (Asia/Kolkata) to avoid date mismatches
date_default_timezone_set('Asia/Kolkata');
try {
    $kolkataTz = new DateTimeZone('Asia/Kolkata');
    $nowKolkata = new DateTime('now', $kolkataTz);
} catch (Throwable $e) {
    $nowKolkata = new DateTime('now');
}
$todayMonthDay = $nowKolkata->format('m-d'); // e.g. "10-16"
$todayYmd      = $nowKolkata->format('Y-m-d'); // e.g. "2026-10-16"

// Ensure MySQL session matches Asia/Kolkata (+05:30) if possible
try {
    $pdo->exec("SET time_zone = '+05:30'");
} catch (Throwable $tzErr) {
    // Non-fatal if server restricts session time_zone
}

// 1. Today's Birthdays (Only active on current day & month in Asia/Kolkata)
try {
    $bdayStmt = $pdo->prepare("
        SELECT 
            u.id, 
            COALESCE(NULLIF(TRIM(u.display_name), ''), CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))) AS name,
            u.profile_photo,
            COALESCE(c.name, '') AS chapter_name,
            u.mobile,
            u.dob
        FROM users u
        LEFT JOIN chapters c ON c.id = u.chapter_id
        WHERE (u.status = 'active' OR u.status = '1' OR u.status IS NULL)
          AND u.dob IS NOT NULL
          AND u.dob != '0000-00-00'
          AND DATE_FORMAT(u.dob, '%m-%d') = :today_md
        ORDER BY name ASC
    ");
    $bdayStmt->execute(['today_md' => $todayMonthDay]);
    $birthdays = $bdayStmt->fetchAll(PDO::FETCH_ASSOC);
    $data['birthdays'] = $birthdays ?: [];
    $data['today_birthdays'] = $data['birthdays'];
} catch (Throwable $e) {
    error_log('Error querying today_birthdays: ' . $e->getMessage());
    $data['birthdays'] = [];
    $data['today_birthdays'] = [];
}

// 2. Today's Anniversaries (Only active on current day & month in Asia/Kolkata)
try {
    // Check whether column is anniversary_date or anniversary or wedding_anniversary
    $annivStmt = $pdo->prepare("
        SELECT 
            u.id, 
            COALESCE(NULLIF(TRIM(u.display_name), ''), CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))) AS name,
            u.profile_photo,
            COALESCE(c.name, '') AS chapter_name,
            u.mobile,
            COALESCE(u.anniversary_date, u.anniversary) AS anniversary_date
        FROM users u
        LEFT JOIN chapters c ON c.id = u.chapter_id
        WHERE (u.status = 'active' OR u.status = '1' OR u.status IS NULL)
          AND (
            (u.anniversary_date IS NOT NULL AND u.anniversary_date != '0000-00-00' AND DATE_FORMAT(u.anniversary_date, '%m-%d') = :today_md1)
            OR
            (u.anniversary IS NOT NULL AND u.anniversary != '0000-00-00' AND DATE_FORMAT(u.anniversary, '%m-%d') = :today_md2)
          )
        ORDER BY name ASC
    ");
    $annivStmt->execute([
        'today_md1' => $todayMonthDay,
        'today_md2' => $todayMonthDay,
    ]);
    $anniversaries = $annivStmt->fetchAll(PDO::FETCH_ASSOC);
    $data['anniversaries'] = $anniversaries ?: [];
    $data['today_anniversaries'] = $data['anniversaries'];
} catch (Throwable $e) {
    // Fallback if u.anniversary doesn't exist as a separate column
    try {
        $annivStmtFallback = $pdo->prepare("
            SELECT 
                u.id, 
                COALESCE(NULLIF(TRIM(u.display_name), ''), CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))) AS name,
                u.profile_photo,
                COALESCE(c.name, '') AS chapter_name,
                u.mobile,
                u.anniversary_date
            FROM users u
            LEFT JOIN chapters c ON c.id = u.chapter_id
            WHERE (u.status = 'active' OR u.status = '1' OR u.status IS NULL)
              AND u.anniversary_date IS NOT NULL
              AND u.anniversary_date != '0000-00-00'
              AND DATE_FORMAT(u.anniversary_date, '%m-%d') = :today_md
            ORDER BY name ASC
        ");
        $annivStmtFallback->execute(['today_md' => $todayMonthDay]);
        $anniversaries = $annivStmtFallback->fetchAll(PDO::FETCH_ASSOC);
        $data['anniversaries'] = $anniversaries ?: [];
        $data['today_anniversaries'] = $data['anniversaries'];
    } catch (Throwable $fallbackErr) {
        error_log('Error querying today_anniversaries: ' . $fallbackErr->getMessage());
        $data['anniversaries'] = [];
        $data['today_anniversaries'] = [];
    }
}

// 3. Upcoming Events (On or after today in Asia/Kolkata)
try {
    $eventStmt = $pdo->prepare("
        SELECT 
            id, 
            title, 
            event_date, 
            start_time, 
            location,
            description
        FROM events
        WHERE (event_date >= :today_ymd)
        ORDER BY event_date ASC
        LIMIT 5
    ");
    $eventStmt->execute(['today_ymd' => $todayYmd]);
    $events = $eventStmt->fetchAll(PDO::FETCH_ASSOC);
    $data['upcoming_events'] = $events ?: [];
    $data['events'] = $data['upcoming_events'];
} catch (Throwable $e) {
    error_log('Error querying upcoming_events: ' . $e->getMessage());
    $data['upcoming_events'] = [];
    $data['events'] = [];
}

// 4. Upcoming Meeting (if null or not set)
if (empty($data['upcoming_meeting'])) {
    try {
        $userChapterId = isset($user['chapter_id']) ? (int)$user['chapter_id'] : 0;
        $mStmt = $pdo->prepare("
            SELECT 
                id, 
                meeting_title AS title, 
                meeting_date AS date, 
                start_time AS time, 
                location
            FROM meetings
            WHERE (meeting_date >= :today_ymd)
              AND (:chapter_id = 0 OR chapter_id = :chapter_id OR chapter_id IS NULL)
            ORDER BY meeting_date ASC
            LIMIT 1
        ");
        $mStmt->execute([
            'today_ymd'  => $todayYmd,
            'chapter_id' => $userChapterId,
        ]);
        $nextMeeting = $mStmt->fetch(PDO::FETCH_ASSOC);
        if ($nextMeeting) {
            $data['upcoming_meeting'] = $nextMeeting;
        }
    } catch (Throwable $e) {
        error_log('Error querying upcoming_meeting: ' . $e->getMessage());
    }
}
