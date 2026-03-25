-- ============================================================================
-- MassKot | Store Ecommerce Module (02_store_ecommerce_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_nutrition_facts ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 1. Catálogo Público (Lectura Universal, Escritura Admin)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "product_categories_select_public" ON product_categories;
CREATE POLICY "product_categories_select_public" ON product_categories FOR SELECT USING (true);
DROP POLICY IF EXISTS "product_categories_all_admin" ON product_categories;
CREATE POLICY "product_categories_all_admin" ON product_categories FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "products_select_public" ON products;
CREATE POLICY "products_select_public" ON products FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "products_all_admin" ON products;
CREATE POLICY "products_all_admin" ON products FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "ingredients_select_public" ON ingredients;
CREATE POLICY "ingredients_select_public" ON ingredients FOR SELECT USING (true);
DROP POLICY IF EXISTS "ingredients_all_admin" ON ingredients;
CREATE POLICY "ingredients_all_admin" ON ingredients FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "product_ingredients_select_public" ON product_ingredients;
CREATE POLICY "product_ingredients_select_public" ON product_ingredients FOR SELECT USING (true);
DROP POLICY IF EXISTS "product_ingredients_all_admin" ON product_ingredients;
CREATE POLICY "product_ingredients_all_admin" ON product_ingredients FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "product_nutrition_facts_select_public" ON product_nutrition_facts;
CREATE POLICY "product_nutrition_facts_select_public" ON product_nutrition_facts FOR SELECT USING (true);
DROP POLICY IF EXISTS "product_nutrition_facts_all_admin" ON product_nutrition_facts;
CREATE POLICY "product_nutrition_facts_all_admin" ON product_nutrition_facts FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "shipping_zones_select_public" ON shipping_zones;
CREATE POLICY "shipping_zones_select_public" ON shipping_zones FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "shipping_zones_all_admin" ON shipping_zones;
CREATE POLICY "shipping_zones_all_admin" ON shipping_zones FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 2. Coupons
-- ----------------------------------------------------------------------------
-- Lectura: Público para poder validar durante checkout si está activo
DROP POLICY IF EXISTS "coupons_select_public" ON coupons;
CREATE POLICY "coupons_select_public" ON coupons FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "coupons_all_admin" ON coupons;
CREATE POLICY "coupons_all_admin" ON coupons FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 3. Product Reviews
-- ----------------------------------------------------------------------------
-- Lectura: Público
DROP POLICY IF EXISTS "product_reviews_select_public" ON product_reviews;
CREATE POLICY "product_reviews_select_public" ON product_reviews FOR SELECT USING (true);

-- Insert: Solo usuarios autenticados para su propio profile_id
DROP POLICY IF EXISTS "product_reviews_insert_auth" ON product_reviews;
CREATE POLICY "product_reviews_insert_auth" ON product_reviews
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND 
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

-- Update: Solo escritura a su propio review
DROP POLICY IF EXISTS "product_reviews_update_owner" ON product_reviews;
CREATE POLICY "product_reviews_update_owner" ON product_reviews
    FOR UPDATE USING (
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

-- Delete: Owner o Admin
DROP POLICY IF EXISTS "product_reviews_delete_owner" ON product_reviews;
CREATE POLICY "product_reviews_delete_owner" ON product_reviews
    FOR DELETE USING (
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "product_reviews_all_admin" ON product_reviews;
CREATE POLICY "product_reviews_all_admin" ON product_reviews
    FOR ALL USING (auth_has_role('admin'));
