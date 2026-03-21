-- ============================================================================
-- MasKot | Complementary Module (06_complementary_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_roles ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 1. Profiles (Usuarios Centrales)
-- ----------------------------------------------------------------------------
-- Lectura: Público solo ve activos. El Dueño y Admin pueden ver incluso si está en espera de eliminación (deleted_at).
DROP POLICY IF EXISTS "profiles_select_public" ON profiles;
CREATE POLICY "profiles_select_public" ON profiles
    FOR SELECT USING (
        deleted_at IS NULL OR 
        user_id = auth.uid()
    );

-- Escritura (UPDATE): El propio usuario puede editar su perfil.
-- Esto le permite solicitar eliminación (deleted_at = NOW()) 
-- o cancelarla (deleted_at = NULL) durante los 30 días.
DROP POLICY IF EXISTS "profiles_update_owner" ON profiles;
CREATE POLICY "profiles_update_owner" ON profiles
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "profiles_all_admin" ON profiles;
CREATE POLICY "profiles_all_admin" ON profiles
    FOR ALL USING (auth_has_role('admin'));

-- ----------------------------------------------------------------------------
-- 2. Roles & Profile_Roles (RBAC Nucleus)
-- ----------------------------------------------------------------------------
-- Roles (Catálogo)
DROP POLICY IF EXISTS "roles_select_auth" ON roles;
CREATE POLICY "roles_select_auth" ON roles
    FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "roles_all_admin" ON roles;
CREATE POLICY "roles_all_admin" ON roles
    FOR ALL USING (auth_has_role('admin'));

-- Profile Roles (Asignaciones)
-- El usuario necesita leer sus propios roles (útil en el frontend).
DROP POLICY IF EXISTS "profile_roles_select_owner" ON profile_roles;
CREATE POLICY "profile_roles_select_owner" ON profile_roles
    FOR SELECT USING (
        profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );

-- Modificar los roles de alguien = SOLO ADMIN
DROP POLICY IF EXISTS "profile_roles_all_admin" ON profile_roles;
CREATE POLICY "profile_roles_all_admin" ON profile_roles
    FOR ALL USING (auth_has_role('admin'));
