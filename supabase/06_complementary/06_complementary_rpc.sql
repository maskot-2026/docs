-- Content from core_rpc.sql
-- ============================================================================
-- MasKot | Core Module (core_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- Trigger: Crear perfil automáticamente al registro
CREATE OR REPLACE FUNCTION handle_new_user_registration()
RETURNS TRIGGER AS $$
BEGIN
    -- Crear perfil desde metadata
    INSERT INTO profiles (id, full_name, phone)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        NEW.raw_user_meta_data->>'phone'
    );
    
    -- Asignar rol 'user' por defecto
    INSERT INTO user_roles (user_id, role_id)
    VALUES (NEW.id, 1);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user_registration();

-- Helper: Verificar si usuario tiene un rol
CREATE OR REPLACE FUNCTION has_role(p_user_id UUID, p_role_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = p_user_id AND r.name = p_role_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper: Obtener roles del usuario actual
CREATE OR REPLACE FUNCTION get_my_roles()
RETURNS TEXT[] AS $$
BEGIN
    RETURN (
        SELECT ARRAY_AGG(r.name)
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;


-- Content from notifications_rpc.sql
-- ============================================================================
-- MasKot | Notifications Module (notifications_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Enviar notificación (placeholder para integración)
CREATE OR REPLACE FUNCTION send_notification(
    p_user_id UUID,
    p_type TEXT,
    p_channel notification_channel,
    p_subject TEXT,
    p_content TEXT
) RETURNS JSONB AS $$
DECLARE
    v_log_id BIGINT;
BEGIN
    -- Registrar intento de notificación
    INSERT INTO notification_logs (user_id, type, channel, subject, content, status)
    VALUES (p_user_id, p_type, p_channel, p_subject, p_content, 'pending')
    RETURNING id INTO v_log_id;
    
    -- TODO: Integrar con servicio de email/push (Resend, OneSignal, etc.)
    -- Por ahora, marcar como enviado
    UPDATE notification_logs SET status = 'sent', sent_at = NOW()
    WHERE id = v_log_id;
    
    RETURN jsonb_build_object('success', true, 'log_id', v_log_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear preferencias por defecto para nuevo usuario
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notification_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created_create_preferences
AFTER INSERT ON profiles
FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();


-- Content from referrals_rpc.sql
-- ============================================================================
-- MasKot | Referrals Module (referrals_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Generar código de referido único para usuario
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
    v_exists BOOLEAN;
BEGIN
    -- Verificar si ya tiene código
    SELECT code INTO v_code FROM referral_codes WHERE user_id = p_user_id;
    IF v_code IS NOT NULL THEN
        RETURN v_code;
    END IF;
    
    -- Generar código único
    LOOP
        v_code := 'MK' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));
        SELECT EXISTS(SELECT 1 FROM referral_codes WHERE code = v_code) INTO v_exists;
        EXIT WHEN NOT v_exists;
    END LOOP;
    
    -- Insertar código
    INSERT INTO referral_codes (user_id, code)
    VALUES (p_user_id, v_code);
    
    RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Aplicar código de referido en checkout
CREATE OR REPLACE FUNCTION apply_referral_code(
    p_referral_code TEXT,
    p_referred_user_id UUID,
    p_order_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_referral_code RECORD;
    v_discount NUMERIC := 20.00; -- Descuento fijo para el referido
    v_reward NUMERIC := 15.00;   -- Recompensa fija para el referidor
BEGIN
    -- Buscar código
    SELECT * INTO v_referral_code FROM referral_codes WHERE code = UPPER(p_referral_code);
    
    IF v_referral_code IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Código no válido');
    END IF;
    
    -- Verificar que no se refiera a sí mismo
    IF v_referral_code.user_id = p_referred_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'No puedes usar tu propio código');
    END IF;
    
    -- Verificar que no haya sido referido antes
    IF EXISTS (SELECT 1 FROM referrals WHERE referred_user_id = p_referred_user_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Ya has sido referido anteriormente');
    END IF;
    
    -- Crear referencia
    INSERT INTO referrals (referrer_id, referred_user_id, order_id, referrer_reward, referred_discount, status)
    VALUES (v_referral_code.user_id, p_referred_user_id, p_order_id, v_reward, v_discount, 'completed');
    
    -- Incrementar contador de usos
    UPDATE referral_codes SET uses_count = uses_count + 1 WHERE id = v_referral_code.id;
    
    RETURN jsonb_build_object('success', true, 'discount_applied', v_discount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Obtener estadísticas de referidos del usuario
CREATE OR REPLACE FUNCTION get_referral_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_code TEXT;
    v_total_referrals INTEGER;
    v_total_rewards NUMERIC;
BEGIN
    -- Obtener o crear código
    v_code := generate_referral_code(p_user_id);
    
    -- Contar referidos completados
    SELECT COUNT(*), COALESCE(SUM(referrer_reward), 0)
    INTO v_total_referrals, v_total_rewards
    FROM referrals
    WHERE referrer_id = p_user_id AND status = 'completed';
    
    RETURN jsonb_build_object(
        'code', v_code,
        'total_referrals', v_total_referrals,
        'total_rewards', v_total_rewards,
        'pending_referrals', (
            SELECT jsonb_agg(jsonb_build_object(
                'referred_user', p.full_name,
                'status', r.status,
                'created_at', r.created_at
            ))
            FROM referrals r
            JOIN profiles p ON p.id = r.referred_user_id
            WHERE r.referrer_id = p_user_id AND r.status = 'pending'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;



