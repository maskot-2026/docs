-- Content from core_perf.sql
-- ============================================================================
-- MasKot | Core Module (core_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes
-- CREATE INDEX idx_perf_profiles_username ON profiles(username) WHERE username IS NOT NULL;
-- CREATE INDEX idx_perf_user_roles_user ON user_roles(user_id);


-- Content from notifications_perf.sql
-- ============================================================================
-- MasKot | Notifications Module (notifications_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes
-- CREATE INDEX idx_perf_notification_logs_user ON notification_logs(user_id);
-- CREATE INDEX idx_perf_notification_logs_status ON notification_logs(status) WHERE status = 'pending';


-- Content from referrals_perf.sql
-- ============================================================================
-- MasKot | Referrals Module (referrals_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes
-- CREATE INDEX idx_perf_referral_codes_code ON referral_codes(code);
-- CREATE INDEX idx_perf_referrals_referrer ON referrals(referrer_id);
-- CREATE INDEX idx_perf_referrals_referred ON referrals(referred_user_id);



