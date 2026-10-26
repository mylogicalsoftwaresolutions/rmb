-- Use these counts inside the existing dashboard.php response for both Web
-- and Flutter. They read the shared referrals table; do not cache or store a
-- separate Web/mobile count.  The range starts at Monday 00:00:00 and ends
-- at the following Monday 00:00:00 (exclusive), which includes all of Sunday.
-- Use the database/application timezone that the referral timestamps use.
SELECT
  COALESCE(SUM(CASE WHEN given_by = :user_id THEN 1 ELSE 0 END), 0) AS referrals_given,
  COALESCE(SUM(CASE WHEN received_by = :user_id THEN 1 ELSE 0 END), 0) AS referrals_received
FROM referrals
WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)
  AND created_at < DATE_ADD(
    DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY),
    INTERVAL 7 DAY
  );

-- Recommended indexes for the dashboard query.
CREATE INDEX idx_referrals_given_created_at ON referrals (given_by, created_at);
CREATE INDEX idx_referrals_received_created_at ON referrals (received_by, created_at);
