-- ============================================================================
-- MassKot | Checkout & Subscriptions Module (03_checkout_subscriptions_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

ALTER TABLE carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;

-- Helper Function para Guest/Session
CREATE OR REPLACE FUNCTION current_session_id() RETURNS TEXT AS $$
    SELECT current_setting('request.headers', true)::json ->> 'x-cart-session-id';
$$ LANGUAGE sql STABLE;

-- ----------------------------------------------------------------------------
-- 1. Carts & Orders (Guest + Auth Support)
-- ----------------------------------------------------------------------------
-- Carritos: Dueño o Guest Session
DROP POLICY IF EXISTS "carts_owner_access" ON carts;
CREATE POLICY "carts_owner_access" ON carts
    FOR ALL USING (
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()) OR
        (session_id IS NOT NULL AND session_id = current_session_id())
    );

DROP POLICY IF EXISTS "carts_all_admin" ON carts;
CREATE POLICY "carts_all_admin" ON carts FOR ALL USING (auth_has_role('admin'));

-- Órdenes: Dueño o Guest Session
DROP POLICY IF EXISTS "orders_owner_access" ON orders;
CREATE POLICY "orders_owner_access" ON orders
    FOR ALL USING (
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()) OR
        (cart_session_id IS NOT NULL AND cart_session_id = current_session_id())
    );

DROP POLICY IF EXISTS "orders_all_admin" ON orders;
CREATE POLICY "orders_all_admin" ON orders FOR ALL USING (auth_has_role('admin'));

-- Order Items: Lectura y escritura vía el Order Parent
DROP POLICY IF EXISTS "order_items_owner_access" ON order_items;
CREATE POLICY "order_items_owner_access" ON order_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM orders o 
            WHERE o.id = order_items.order_id 
              AND (
                  o.profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()) OR 
                  (o.cart_session_id IS NOT NULL AND o.cart_session_id = current_session_id())
              )
        )
    );

DROP POLICY IF EXISTS "order_items_all_admin" ON order_items;
CREATE POLICY "order_items_all_admin" ON order_items FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 2. Entidades Persistentes (Solo Auth: Addresses, Billing, Tokens, Subs)
-- ----------------------------------------------------------------------------

-- Shipping Addresses
DROP POLICY IF EXISTS "shipping_owner_access" ON shipping_addresses;
CREATE POLICY "shipping_owner_access" ON shipping_addresses
    FOR ALL USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "shipping_all_admin" ON shipping_addresses;
CREATE POLICY "shipping_all_admin" ON shipping_addresses FOR ALL USING (auth_has_role('admin'));

-- Billing Profiles
DROP POLICY IF EXISTS "billing_owner_access" ON billing_profiles;
CREATE POLICY "billing_owner_access" ON billing_profiles
    FOR ALL USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "billing_all_admin" ON billing_profiles;
CREATE POLICY "billing_all_admin" ON billing_profiles FOR ALL USING (auth_has_role('admin'));

-- Payment Tokens (Importante: El cliente NUNCA debe poder insert/update directamente aquí, es vía backend Stripe/MP)
-- Así que damos SELECT y DELETE (para borrar su propia tarjeta) pero NO INSERT ni UPDATE.
DROP POLICY IF EXISTS "tokens_select_delete_owner" ON payment_tokens;
CREATE POLICY "tokens_select_delete_owner" ON payment_tokens
    FOR SELECT USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "tokens_delete_owner" ON payment_tokens;
CREATE POLICY "tokens_delete_owner" ON payment_tokens
    FOR DELETE USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "tokens_all_admin" ON payment_tokens;
CREATE POLICY "tokens_all_admin" ON payment_tokens FOR ALL USING (auth_has_role('admin'));

-- Subscriptions 
DROP POLICY IF EXISTS "subscriptions_owner_access" ON subscriptions;
CREATE POLICY "subscriptions_owner_access" ON subscriptions
    FOR ALL USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS "subscriptions_all_admin" ON subscriptions;
CREATE POLICY "subscriptions_all_admin" ON subscriptions FOR ALL USING (auth_has_role('admin'));

-- Subscription History (Solo Lectura para owner)
DROP POLICY IF EXISTS "subscription_history_select_owner" ON subscription_history;
CREATE POLICY "subscription_history_select_owner" ON subscription_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM subscriptions s 
            WHERE s.id = subscription_id 
              AND s.profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
        )
    );
DROP POLICY IF EXISTS "sub_history_all_admin" ON subscription_history;
CREATE POLICY "sub_history_all_admin" ON subscription_history FOR ALL USING (auth_has_role('admin'));
