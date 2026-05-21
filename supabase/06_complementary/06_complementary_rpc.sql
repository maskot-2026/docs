-- Content from core_rpc.sql
-- ============================================================================
-- MassKot | Core Module (core_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- Trigger: Crear perfil automáticamente al registro
CREATE OR REPLACE FUNCTION handle_new_user_registration()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_id BIGINT;
    v_username   TEXT;
    v_full_name  TEXT;
BEGIN
    -- Resolver username:
    --   • Registro por email → viene en raw_user_meta_data->>'username'
    --   • OAuth (Google)     → se extrae el prefijo del email (ej: j.huanca4141@gmail.com → j.huanca4141)
    --   • Conflicto          → se agrega sufijo aleatorio de 4 chars (ej: j.huanca4141_a3f7)
    v_username := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''),
        split_part(NEW.email, '@', 1)
    );

    -- Si el username ya existe, agregar sufijo para evitar conflicto de unicidad
    IF EXISTS (SELECT 1 FROM profiles WHERE username = v_username) THEN
        v_username := v_username || '_' || substring(replace(gen_random_uuid()::text, '-', ''), 1, 4);
    END IF;

    -- Resolver full_name (siempre disponible en ambos flujos)
    v_full_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
        v_username
    );

    -- Crear perfil
    INSERT INTO profiles (user_id, username, full_name, avatar_url)
    VALUES (
        NEW.id,
        v_username,
        v_full_name,
        NEW.raw_user_meta_data->>'avatar_url'
    ) RETURNING id INTO v_profile_id;
    
    -- Asignar rol por defecto resolviendo su ID por nombre
    INSERT INTO profile_roles (profile_id, role_id)
    SELECT v_profile_id, id FROM roles WHERE name = 'user';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public SET row_security = off;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user_registration();

-- Helper: Verificar si el usuario actual tiene un rol (gestiona jerarquía básica y RLS)
-- STABLE + SECURITY DEFINER: optimiza consultas y evita dependencias circulares con RLS
CREATE OR REPLACE FUNCTION auth_has_role(p_required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM profile_roles pr
        JOIN roles r ON r.id = pr.role_id
        JOIN profiles p ON p.id = pr.profile_id
        WHERE p.user_id = auth.uid() 
          AND p.deleted_at IS NULL
          AND (
              r.name = p_required_role                                    -- Tiene el rol exacto
              OR (p_required_role = 'user' AND r.name IN ('professional', 'admin'))-- 'professional' y 'admin' heredan de 'user'
              OR (p_required_role = 'professional' AND r.name = 'admin')           -- 'admin' hereda de 'professional'
              OR r.name = 'admin'                                         -- 'admin' tiene todos los permisos
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Helper: Obtener roles del usuario actual (vía su perfil activo)
CREATE OR REPLACE FUNCTION get_my_roles()
RETURNS TEXT[] AS $$
BEGIN
    RETURN (
        SELECT ARRAY_AGG(r.name)
        FROM profile_roles pr
        JOIN roles r ON r.id = pr.role_id
        JOIN profiles p ON p.id = pr.profile_id
        WHERE p.user_id = auth.uid() AND p.deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
