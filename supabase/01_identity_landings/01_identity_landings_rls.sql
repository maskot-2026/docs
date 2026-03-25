-- ============================================================================
-- MassKot | Identity & Landings Module (01_identity_landings_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

-- Habilitar RLS en todas las tablas del módulo
ALTER TABLE home_page_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE about_page_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE faq_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 1. home_page_config
-- ----------------------------------------------------------------------------
-- Lectura: Público
DROP POLICY IF EXISTS "home_page_config_select_public" ON home_page_config;
CREATE POLICY "home_page_config_select_public" ON home_page_config
    FOR SELECT USING (true);

-- Escritura: Solo Admins
DROP POLICY IF EXISTS "home_page_config_all_admin" ON home_page_config;
CREATE POLICY "home_page_config_all_admin" ON home_page_config
    FOR ALL USING (auth_has_role('admin'));


-- ----------------------------------------------------------------------------
-- 2. about_page_config
-- ----------------------------------------------------------------------------
-- Lectura: Público
DROP POLICY IF EXISTS "about_page_config_select_public" ON about_page_config;
CREATE POLICY "about_page_config_select_public" ON about_page_config
    FOR SELECT USING (true);

-- Escritura: Solo Admins
DROP POLICY IF EXISTS "about_page_config_all_admin" ON about_page_config;
CREATE POLICY "about_page_config_all_admin" ON about_page_config
    FOR ALL USING (auth_has_role('admin'));


-- ----------------------------------------------------------------------------
-- 3. faq_categories & faqs
-- ----------------------------------------------------------------------------
-- Lectura: Público
DROP POLICY IF EXISTS "faq_categories_select_public" ON faq_categories;
CREATE POLICY "faq_categories_select_public" ON faq_categories
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "faqs_select_public" ON faqs;
CREATE POLICY "faqs_select_public" ON faqs
    FOR SELECT USING (true);

-- Escritura: Solo Admins
DROP POLICY IF EXISTS "faq_categories_all_admin" ON faq_categories;
CREATE POLICY "faq_categories_all_admin" ON faq_categories
    FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "faqs_all_admin" ON faqs;
CREATE POLICY "faqs_all_admin" ON faqs
    FOR ALL USING (auth_has_role('admin'));


-- ----------------------------------------------------------------------------
-- 4. blog_categories & blog_posts
-- ----------------------------------------------------------------------------
-- Lectura: Público (Solo posts publicados para el público, admin ve todos)
DROP POLICY IF EXISTS "blog_categories_select_public" ON blog_categories;
CREATE POLICY "blog_categories_select_public" ON blog_categories
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "blog_posts_select_public" ON blog_posts;
CREATE POLICY "blog_posts_select_public" ON blog_posts
    FOR SELECT USING (published_at IS NOT NULL AND published_at <= NOW());

-- Escritura: Solo Admins
DROP POLICY IF EXISTS "blog_categories_all_admin" ON blog_categories;
CREATE POLICY "blog_categories_all_admin" ON blog_categories
    FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "blog_posts_all_admin" ON blog_posts;
CREATE POLICY "blog_posts_all_admin" ON blog_posts
    FOR ALL USING (auth_has_role('admin'));
