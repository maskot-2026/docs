-- Content from cms_rls.sql
-- ============================================================================
-- MasKot | CMS Module (cms_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies when ready for production
-- Example patterns:
-- ALTER TABLE testimonials ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Public read testimonials" ON testimonials FOR SELECT USING (true);
-- CREATE POLICY "Admin manage testimonials" ON testimonials FOR ALL USING (auth.jwt() ->> 'role' = 'admin');



