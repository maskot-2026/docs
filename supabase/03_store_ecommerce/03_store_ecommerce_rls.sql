-- Content from store_rls.sql
-- ============================================================================
-- MasKot | Store Module (store_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE products ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Public read active products" ON products FOR SELECT USING (status = 'active' AND is_active = TRUE);

-- ALTER TABLE carts ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users manage their own carts" ON carts FOR ALL USING (auth.uid() = user_id);



