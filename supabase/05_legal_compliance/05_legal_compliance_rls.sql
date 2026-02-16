-- Content from legal_rls.sql
-- ============================================================================
-- MasKot | Legal Module (legal_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE legal_documents ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Public read legal documents" ON legal_documents FOR SELECT USING (true);

-- ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Admins can manage complaints" ON complaints FOR ALL USING (has_role(auth.uid(), 'admin'));



