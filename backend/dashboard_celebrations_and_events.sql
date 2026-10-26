-- Queries to add to api_flutter/dashboard.php (and api/dashboard.php)
-- for Today's Birthdays, Anniversaries, and Upcoming Events.
-- Uses Asia/Kolkata timezone (+05:30) so events show strictly on the exact calendar day.

-- Set connection timezone to Asia/Kolkata
SET time_zone = '+05:30';

-- 1. Today's Birthdays
-- Matches month and day of dob with current date in Asia/Kolkata (+05:30).
-- Shows on the birthday itself, not in past or future dates.
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
  AND DATE_FORMAT(u.dob, '%m-%d') = DATE_FORMAT(CONVERT_TZ(NOW(), @@session.time_zone, '+05:30'), '%m-%d')
ORDER BY name ASC;

-- 2. Today's Anniversaries
-- Matches month and day of anniversary_date with current date in Asia/Kolkata (+05:30).
-- Shows on the anniversary itself, not in past or future dates.
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
    (u.anniversary_date IS NOT NULL AND u.anniversary_date != '0000-00-00' AND DATE_FORMAT(u.anniversary_date, '%m-%d') = DATE_FORMAT(CONVERT_TZ(NOW(), @@session.time_zone, '+05:30'), '%m-%d'))
    OR
    (u.anniversary IS NOT NULL AND u.anniversary != '0000-00-00' AND DATE_FORMAT(u.anniversary, '%m-%d') = DATE_FORMAT(CONVERT_TZ(NOW(), @@session.time_zone, '+05:30'), '%m-%d'))
  )
ORDER BY name ASC;

-- 3. Upcoming Events (On or after today in Asia/Kolkata)
SELECT 
    id, 
    title, 
    event_date, 
    start_time, 
    location,
    description
FROM events
WHERE (event_date >= DATE(CONVERT_TZ(NOW(), @@session.time_zone, '+05:30')))
ORDER BY event_date ASC
LIMIT 5;

-- 4. Upcoming Meeting (Next upcoming meeting for the user's chapter)
SELECT 
    id, 
    meeting_title AS title, 
    meeting_date AS date, 
    start_time AS time, 
    location
FROM meetings
WHERE (meeting_date >= DATE(CONVERT_TZ(NOW(), @@session.time_zone, '+05:30')))
  AND (:chapter_id = 0 OR chapter_id = :chapter_id OR chapter_id IS NULL)
ORDER BY meeting_date ASC
LIMIT 1;
