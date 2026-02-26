-- ============================================================================
-- MasKot | B2B Professional Channel Module (07_b2b_professional_rpc.sql)
-- RPC Implementations - Fase 2
-- ============================================================================

-- ============================================================================
-- HU-7.1: Registro Profesional
-- ============================================================================

-- RPC: Crear solicitud de cuenta B2B
CREATE OR REPLACE FUNCTION create_b2b_account_request(
    p_profile_id BIGINT,
    p_business_name TEXT,
    p_ruc TEXT,
    p_professional_affix TEXT,
    p_professional_type TEXT,
    p_document_url TEXT
) RETURNS JSONB AS $$
DECLARE
    v_account_id BIGINT;
BEGIN
    -- Validar formato de RUC (11 dígitos)
    IF LENGTH(p_ruc) != 11 OR p_ruc !~ '^[0-9]+$' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'RUC inválido: debe tener 11 dígitos numéricos'
        );
    END IF;
    
    -- Verificar si ya existe una solicitud para este usuario
    IF EXISTS (SELECT 1 FROM b2b_accounts WHERE profile_id = p_profile_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Ya existe una solicitud de cuenta B2B para este usuario'
        );
    END IF;
    
    -- Verificar si el RUC ya está registrado
    IF EXISTS (SELECT 1 FROM b2b_accounts WHERE ruc = p_ruc) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Este RUC ya está registrado en el sistema'
        );
    END IF;
    
    -- Crear registro de cuenta B2B
    INSERT INTO b2b_accounts (
        profile_id,
        business_name,
        ruc,
        professional_affix,
        professional_type,
        document_url,
        status
    ) VALUES (
        p_profile_id,
        p_business_name,
        p_ruc,
        p_professional_affix,
        p_professional_type,
        p_document_url,
        'pending'
    ) RETURNING id INTO v_account_id;
    
    -- TODO: Enviar email de confirmación de solicitud
    -- (Implementar con Supabase Edge Functions o trigger)
    
    RETURN jsonb_build_object(
        'success', true,
        'account_id', v_account_id,
        'status', 'pending',
        'message', 'Solicitud enviada. Será revisada en las próximas 24-48 horas'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HU-7.2: Catálogo B2B con Precios Especiales
-- ============================================================================

-- RPC: Obtener productos B2B con validación de cuenta
CREATE OR REPLACE FUNCTION get_b2b_products(p_profile_id BIGINT)
RETURNS TABLE (
    product_id BIGINT,
    name TEXT,
    sku TEXT,
    description TEXT,
    regular_price NUMERIC,
    b2b_price NUMERIC,
    discount_pct NUMERIC,
    images TEXT[],
    weight_options JSONB,
    stock_quantity INTEGER
) AS $$
BEGIN
    -- Validar que usuario tenga cuenta B2B aprobada
    IF NOT EXISTS (
        SELECT 1 FROM b2b_accounts
        WHERE profile_id = p_profile_id AND status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Usuario no tiene cuenta B2B aprobada';
    END IF;
    
    -- Retornar productos B2B con precios especiales
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.sku,
        p.description,
        p.price AS regular_price,
        p.b2b_price,
        ROUND((1 - p.b2b_price / p.price) * 100, 1) AS discount_pct,
        p.images,
        p.weight_options,
        p.stock_quantity
    FROM products p
    WHERE p.is_b2b_product = TRUE 
      AND p.b2b_price IS NOT NULL
      AND p.status = 'active'
      AND p.is_active = TRUE
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Verificar elegibilidad B2B de usuario
CREATE OR REPLACE FUNCTION check_b2b_eligibility(p_profile_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
BEGIN
    -- Buscar cuenta B2B del usuario
    SELECT * INTO v_account 
    FROM b2b_accounts 
    WHERE profile_id = p_profile_id;
    
    IF v_account IS NULL THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'status', 'not_registered',
            'message', 'No tiene cuenta profesional registrada'
        );
    END IF;
    
    IF v_account.status = 'approved' THEN
        RETURN jsonb_build_object(
            'eligible', true,
            'status', 'approved',
            'business_name', v_account.business_name,
            'ruc', v_account.ruc,
            'approved_at', v_account.approved_at
        );
    ELSIF v_account.status = 'pending' THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'status', 'pending',
            'message', 'Su solicitud está en revisión'
        );
    ELSIF v_account.status = 'rejected' THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'status', 'rejected',
            'message', 'Solicitud rechazada',
            'rejection_reason', v_account.rejection_reason
        );
    ELSE
        RETURN jsonb_build_object(
            'eligible', false,
            'status', v_account.status,
            'message', 'Cuenta suspendida o inactiva'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- Admin RPCs (para HU-5.4: Gestión de Cuentas Profesionales)
-- ============================================================================

-- RPC: Aprobar cuenta B2B
CREATE OR REPLACE FUNCTION approve_b2b_account(
    p_account_id BIGINT,
    p_admin_profile_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
BEGIN
    -- Obtener cuenta
    SELECT * INTO v_account FROM b2b_accounts WHERE id = p_account_id;
    
    IF v_account IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cuenta no encontrada');
    END IF;
    
    IF v_account.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden aprobar cuentas pendientes');
    END IF;
    
    -- Actualizar estado
    UPDATE b2b_accounts
    SET status = 'approved',
        approved_by = p_admin_profile_id,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Asignar rol B2B resolviendo su ID por nombre
    INSERT INTO profile_roles (profile_id, role_id)
    SELECT v_account.profile_id, id FROM roles WHERE name = 'b2b'
    ON CONFLICT (profile_id, role_id) DO NOTHING;
    
    -- TODO: Enviar email de aprobación al usuario
    -- (Implementar con Supabase Edge Functions)
    
    RETURN jsonb_build_object(
        'success', true,
        'account_id', p_account_id,
        'message', 'Cuenta B2B aprobada exitosamente'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Rechazar cuenta B2B
CREATE OR REPLACE FUNCTION reject_b2b_account(
    p_account_id BIGINT,
    p_admin_profile_id BIGINT,
    p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
BEGIN
    -- Validar motivo
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Debe proporcionar un motivo de rechazo');
    END IF;
    
    -- Obtener cuenta
    SELECT * INTO v_account FROM b2b_accounts WHERE id = p_account_id;
    
    IF v_account IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cuenta no encontrada');
    END IF;
    
    IF v_account.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden rechazar cuentas pendientes');
    END IF;
    
    -- Actualizar estado
    UPDATE b2b_accounts
    SET status = 'rejected',
        rejection_reason = p_reason,
        approved_by = p_admin_profile_id,  -- Registro de quién rechazó
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- TODO: Enviar email de rechazo con motivo
    -- (Implementar con Supabase Edge Functions)
    
    RETURN jsonb_build_object(
        'success', true,
        'account_id', p_account_id,
        'message', 'Cuenta B2B rechazada'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Suspender/Reactivar cuenta B2B
CREATE OR REPLACE FUNCTION toggle_b2b_account_status(
    p_account_id BIGINT,
    p_admin_profile_id BIGINT,
    p_suspend BOOLEAN
) RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
    v_new_status b2b_account_status;
BEGIN
    -- Obtener cuenta
    SELECT * INTO v_account FROM b2b_accounts WHERE id = p_account_id;
    
    IF v_account IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cuenta no encontrada');
    END IF;
    
    -- Determinar nuevo estado
    IF p_suspend THEN
        IF v_account.status != 'approved' THEN
            RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden suspender cuentas aprobadas');
        END IF;
        v_new_status := 'suspended';
    ELSE
        IF v_account.status != 'suspended' THEN
            RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden reactivar cuentas suspendidas');
        END IF;
        v_new_status := 'approved';
    END IF;
    
    -- Actualizar estado
    UPDATE b2b_accounts
    SET status = v_new_status,
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Actualizar rol del usuario resolviendo su ID por nombre
    IF v_new_status = 'approved' THEN
        INSERT INTO profile_roles (profile_id, role_id)
        SELECT v_account.profile_id, id FROM roles WHERE name = 'b2b'
        ON CONFLICT (profile_id, role_id) DO NOTHING;
    ELSE
        DELETE FROM profile_roles
        WHERE profile_id = v_account.profile_id AND role_id = (SELECT id FROM roles WHERE name = 'b2b');
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'account_id', p_account_id,
        'new_status', v_new_status,
        'message', CASE 
            WHEN p_suspend THEN 'Cuenta suspendida exitosamente'
            ELSE 'Cuenta reactivada exitosamente'
        END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
