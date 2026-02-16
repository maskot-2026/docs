-- Content from orders_rls.sql
-- ============================================================================
-- MasKot | Orders Module (orders_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view their own orders" ON orders FOR SELECT USING (auth.uid() = user_id);
-- CREATE POLICY "Admins can manage all orders" ON orders FOR ALL USING (has_role(auth.uid(), 'admin'));

-- ALTER TABLE shipping_addresses ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users manage their own addresses" ON shipping_addresses FOR ALL USING (auth.uid() = user_id);


-- Content from subscriptions_rls.sql
-- ============================================================================
-- MasKot | Subscriptions Module (subscriptions_rls.sql)
-- Row Level Security Policies - Phase 2
-- ============================================================================

-- TODO: Add RLS policies
-- ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users manage their own subscriptions" ON subscriptions FOR ALL USING (auth.uid() = user_id);



