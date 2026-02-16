-- Content from pets_rls.sql
-- ============================================================================
-- MasKot | Pets Module (pets_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE pet_profiles ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can manage their own pets" ON pet_profiles FOR ALL USING (auth.uid() = user_id);


-- Content from quiz_rls.sql
-- ============================================================================
-- MasKot | Quiz Module (quiz_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE quiz_sessions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view their own quiz sessions" ON quiz_sessions FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);



