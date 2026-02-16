-- Content from admin_rls.sql
-- ============================================================================
-- MasKot | Admin Module (admin_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies (admin-only access)
-- ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Admins manage inventory" ON inventory_movements FOR ALL USING (has_role(auth.uid(), 'admin'));

-- ALTER TABLE stock_alerts ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Admins manage stock alerts" ON stock_alerts FOR ALL USING (has_role(auth.uid(), 'admin'));



