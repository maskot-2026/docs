-- Content from pets_perf.sql
-- ============================================================================
-- MasKot | Pets Module (pets_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes
-- CREATE INDEX idx_perf_pet_profiles_user ON pet_profiles(user_id);
-- CREATE INDEX idx_perf_recommendations_pet ON recommendations(pet_profile_id);


-- Content from quiz_perf.sql
-- ============================================================================
-- MasKot | Quiz Module (quiz_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes when needed
-- CREATE INDEX idx_perf_quiz_sessions_user ON quiz_sessions(user_id);
-- CREATE INDEX idx_perf_quiz_sessions_completed ON quiz_sessions(completed_at) WHERE completed_at IS NOT NULL;
-- CREATE INDEX idx_perf_pet_breeds_type ON pet_breeds(pet_type);



