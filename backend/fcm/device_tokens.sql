CREATE TABLE IF NOT EXISTS device_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  fcm_token VARCHAR(512) NOT NULL,
  platform ENUM('android', 'ios', 'web') NOT NULL DEFAULT 'android',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_device_tokens_token (fcm_token),
  KEY idx_device_tokens_user (user_id),
  CONSTRAINT fk_device_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- If device_tokens already exists, alter platform column to allow 'web':
-- ALTER TABLE device_tokens MODIFY COLUMN platform ENUM('android', 'ios', 'web') NOT NULL DEFAULT 'android';

-- Makes send_referral idempotent across Web/Mobile retries.
CREATE TABLE IF NOT EXISTS referral_notification_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  referral_id BIGINT UNSIGNED NOT NULL,
  recipient_user_id BIGINT UNSIGNED NOT NULL,
  fcm_message_names JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_referral_notification (referral_id, recipient_user_id),
  KEY idx_referral_notification_recipient (recipient_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Makes send_r2r idempotent across Web/Mobile retries.
CREATE TABLE IF NOT EXISTS r2r_notification_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  r2r_id BIGINT UNSIGNED NOT NULL,
  recipient_user_id BIGINT UNSIGNED NOT NULL,
  fcm_message_names JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_r2r_notification (r2r_id, recipient_user_id),
  KEY idx_r2r_notification_recipient (recipient_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Makes send_cnote idempotent across Web/Mobile retries.
CREATE TABLE IF NOT EXISTS cnote_notification_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cnote_id BIGINT UNSIGNED NOT NULL,
  recipient_user_id BIGINT UNSIGNED NOT NULL,
  fcm_message_names JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cnote_notification (cnote_id, recipient_user_id),
  KEY idx_cnote_notification_recipient (recipient_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Makes send_testimonial idempotent across Web/Mobile retries.
CREATE TABLE IF NOT EXISTS testimonial_notification_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  testimonial_id BIGINT UNSIGNED NOT NULL,
  recipient_user_id BIGINT UNSIGNED NOT NULL,
  fcm_message_names JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_testimonial_notification (testimonial_id, recipient_user_id),
  KEY idx_testimonial_notification_recipient (recipient_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
