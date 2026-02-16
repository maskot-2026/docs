-- Content from core_rls.sql
-- ============================================================================
-- MasKot | Core Module (core_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view all profiles" ON profiles FOR SELECT USING (true);
-- CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view their own roles" ON user_roles FOR SELECT USING (auth.uid() = user_id);
-- CREATE POLICY "Admins can manage roles" ON user_roles FOR ALL USING (has_role(auth.uid(), 'admin'));


-- Content from notifications_rls.sql
-- ============================================================================
-- MasKot | Notifications Module (notifications_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users manage their own preferences" ON notification_preferences FOR ALL USING (auth.uid() = user_id);

-- ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users view their own notifications" ON notification_logs FOR SELECT USING (auth.uid() = user_id);


-- Content from referrals_rls.sql
-- ============================================================================
-- MasKot | Referrals Module (referrals_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users manage their own referral code" ON referral_codes FOR ALL USING (auth.uid() = user_id);

-- ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users view their own referrals" ON referrals FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_user_id);



