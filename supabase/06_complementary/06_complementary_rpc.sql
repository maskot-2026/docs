-- Content from core_rpc.sql
-- ============================================================================
-- MasKot | Core Module (core_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- Trigger: Crear perfil automáticamente al registro
CREATE OR REPLACE FUNCTION handle_new_user_registration()
RETURNS TRIGGER AS $$
DECLARE
    v_profile_id BIGINT;
BEGIN
    -- Crear perfil desde metadata
    INSERT INTO profiles (user_id, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    ) RETURNING id INTO v_profile_id;
    
    -- Asignar rol por defecto resolviendo su ID por nombre
    INSERT INTO profile_roles (profile_id, role_id)
    SELECT v_profile_id, id FROM roles WHERE name = 'user';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
              OR (p_required_role = 'user' AND r.name IN ('b2b', 'admin'))-- 'b2b' y 'admin' heredan de 'user'
              OR (p_required_role = 'b2b' AND r.name = 'admin')           -- 'admin' hereda de 'b2b'
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


-- Content from notifications_rpc.sql
-- ============================================================================
-- MasKot | Notifications Module (notifications_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Enviar notificación (placeholder para integración)
CREATE OR REPLACE FUNCTION send_notification(
    p_profile_id BIGINT,
    p_type TEXT,
    p_channel notification_channel,
    p_subject TEXT,
    p_content TEXT
) RETURNS JSONB AS $$
DECLARE
    v_log_id BIGINT;
BEGIN
    -- Registrar intento de notificación
    INSERT INTO notification_logs (profile_id, type, channel, subject, content, status)
    VALUES (p_profile_id, p_type, p_channel, p_subject, p_content, 'pending')
    RETURNING id INTO v_log_id;
    
    -- TODO: Integrar con servicio de email/push (Resend, OneSignal, etc.)
    -- Por ahora, marcar como enviado
    UPDATE notification_logs SET status = 'sent', sent_at = NOW()
    WHERE id = v_log_id;
    
    RETURN jsonb_build_object('success', true, 'log_id', v_log_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear preferencias por defecto para nuevo perfil
CREATE OR REPLACE FUNCTION handle_new_profile_created()
RETURNS TRIGGER AS $$
BEGIN
    -- Preferencias de notificación
    INSERT INTO notification_preferences (profile_id)
    VALUES (NEW.id)
    ON CONFLICT (profile_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created_setup
AFTER INSERT ON profiles
FOR EACH ROW EXECUTE FUNCTION handle_new_profile_created();


-- Content from referrals_rpc.sql

