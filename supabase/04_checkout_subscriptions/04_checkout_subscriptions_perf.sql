-- Content from orders_perf.sql
-- ============================================================================
-- MasKot | Orders Module (orders_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes
-- CREATE INDEX idx_perf_orders_user ON orders(user_id);
-- CREATE INDEX idx_perf_orders_status ON orders(status);
-- CREATE INDEX idx_perf_orders_created ON orders(created_at DESC);
-- CREATE INDEX idx_perf_order_items_order ON order_items(order_id);
-- CREATE INDEX idx_perf_shipping_addresses_user ON shipping_addresses(user_id);


-- Content from subscriptions_perf.sql
-- ============================================================================
-- MasKot | Subscriptions Module (subscriptions_perf.sql)
-- Performance Indexes - Phase 2
-- ============================================================================

-- TODO: Add performance indexes
-- CREATE INDEX idx_perf_subscriptions_user ON subscriptions(user_id);
-- CREATE INDEX idx_perf_subscriptions_status ON subscriptions(status) WHERE status = 'active';
-- CREATE INDEX idx_perf_subscriptions_next_billing ON subscriptions(next_billing_date);



