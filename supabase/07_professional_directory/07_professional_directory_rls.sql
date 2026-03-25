-- ============================================================================
-- MassKot | Professional Directory Module (07_professional_directory_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

ALTER TABLE professional_page_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_specialties ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_reviews ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 1. Configuraciones Globales y Catálogos (Lectura Pública, Edición Admin)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "prof_config_select_public" ON professional_page_config;
CREATE POLICY "prof_config_select_public" ON professional_page_config FOR SELECT USING (true);
DROP POLICY IF EXISTS "prof_config_all_admin" ON professional_page_config;
CREATE POLICY "prof_config_all_admin" ON professional_page_config FOR ALL USING (auth_has_role('admin'));

DROP POLICY IF EXISTS "prof_specialties_select_public" ON professional_specialties;
CREATE POLICY "prof_specialties_select_public" ON professional_specialties FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "prof_specialties_all_admin" ON professional_specialties;
CREATE POLICY "prof_specialties_all_admin" ON professional_specialties FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 2. Professional Profiles (Directorio Público e Información B2B)
-- ----------------------------------------------------------------------------
-- Lectura: Público puede ver solo aprobados y publicados
DROP POLICY IF EXISTS "prof_profiles_select_public" ON professional_profiles;
CREATE POLICY "prof_profiles_select_public" ON professional_profiles
    FOR SELECT USING (
        (status = 'approved' AND is_published = true) OR 
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

-- Actualización: El propio profesional puede actualizar sus datos
DROP POLICY IF EXISTS "prof_profiles_update_owner" ON professional_profiles;
CREATE POLICY "prof_profiles_update_owner" ON professional_profiles
    FOR UPDATE USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

-- Insert: NO se da INSERT de política directa, porque la creación es mediante el
-- RPC `create_professional_account_request` que inyecta los datos con validaciones estrictas.

DROP POLICY IF EXISTS "prof_profiles_all_admin" ON professional_profiles;
CREATE POLICY "prof_profiles_all_admin" ON professional_profiles FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 3. Professional Services & Availability
-- ----------------------------------------------------------------------------
-- Lectura Pública
DROP POLICY IF EXISTS "prof_services_select_public" ON professional_services;
CREATE POLICY "prof_services_select_public" ON professional_services FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "prof_availability_select_public" ON professional_availability;
CREATE POLICY "prof_availability_select_public" ON professional_availability FOR SELECT USING (is_active = true);

-- CRUD Owner
DROP POLICY IF EXISTS "prof_services_all_owner" ON professional_services;
CREATE POLICY "prof_services_all_owner" ON professional_services
    FOR ALL USING (
        professional_profile_id = (
            SELECT id FROM professional_profiles WHERE profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "prof_availability_all_owner" ON professional_availability;
CREATE POLICY "prof_availability_all_owner" ON professional_availability
    FOR ALL USING (
        professional_profile_id = (
            SELECT id FROM professional_profiles WHERE profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "prof_services_all_admin" ON professional_services;
CREATE POLICY "prof_services_all_admin" ON professional_services FOR ALL USING (auth_has_role('admin'));
DROP POLICY IF EXISTS "prof_availability_all_admin" ON professional_availability;
CREATE POLICY "prof_availability_all_admin" ON professional_availability FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 4. Professional Appointments (Citas Mutuas)
-- ----------------------------------------------------------------------------
-- Lectura: Solo el Cliente (Dueño del appointment) o el Profesional (Quien recibe)
DROP POLICY IF EXISTS "prof_appointments_select_mutual" ON professional_appointments;
CREATE POLICY "prof_appointments_select_mutual" ON professional_appointments
    FOR SELECT USING (
        client_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()) OR
        professional_profile_id = (
            SELECT id FROM professional_profiles WHERE profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
        )
    );

-- Insert: Solo Clientes autenticados
DROP POLICY IF EXISTS "prof_appointments_insert_client" ON professional_appointments;
CREATE POLICY "prof_appointments_insert_client" ON professional_appointments
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND
        client_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

-- Update: Ambos pueden actualizar pero típicamente con reglas de negocio.
DROP POLICY IF EXISTS "prof_appointments_update_mutual" ON professional_appointments;
CREATE POLICY "prof_appointments_update_mutual" ON professional_appointments
    FOR UPDATE USING (
        client_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()) OR
        professional_profile_id = (
            SELECT id FROM professional_profiles WHERE profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "prof_appointments_all_admin" ON professional_appointments;
CREATE POLICY "prof_appointments_all_admin" ON professional_appointments FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 5. Professional Reviews
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "prof_reviews_select_public" ON professional_reviews;
CREATE POLICY "prof_reviews_select_public" ON professional_reviews FOR SELECT USING (true);

-- Insert: Cliente solo puede hacer review después de una cita aprobada/marcada completa (idealmente).
DROP POLICY IF EXISTS "prof_reviews_insert_client" ON professional_reviews;
CREATE POLICY "prof_reviews_insert_client" ON professional_reviews
    FOR INSERT WITH CHECK (
        client_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

DROP POLICY IF EXISTS "prof_reviews_update_client" ON professional_reviews;
CREATE POLICY "prof_reviews_update_client" ON professional_reviews
    FOR UPDATE USING (client_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "prof_reviews_all_admin" ON professional_reviews;
CREATE POLICY "prof_reviews_all_admin" ON professional_reviews FOR ALL USING (auth_has_role('admin'));
