-- ============================================================================
-- MasKot | Professional Directory Channel Module (07_professional_directory_rpc.sql)
-- RPC Implementations - Fase 2
-- ============================================================================

-- ============================================================================
-- HU-7.1: Registro Profesional
-- ============================================================================

-- RPC: Crear solicitud de cuenta profesional
CREATE OR REPLACE FUNCTION create_professional_account_request(
    p_profile_id BIGINT,
    p_business_name TEXT,
    p_ruc TEXT,
    p_public_name TEXT,
    p_title TEXT,
    p_document_url TEXT,
    p_specialty_id INTEGER
) RETURNS JSONB AS $$
DECLARE
    v_account_id BIGINT;
BEGIN
    -- Validar formato de RUC (11 dígitos)
    IF LENGTH(p_ruc) != 11 OR p_ruc !~ '^[0-9]+$' THEN
        RETURN jsonb_build_object(
            'success', false,
            'detail', 'RUC inválido: debe tener 11 dígitos numéricos'
        );
    END IF;
    
    -- Verificar si ya existe un perfil para este usuario
    IF EXISTS (SELECT 1 FROM professional_profiles WHERE id = p_profile_id) THEN
        RAISE EXCEPTION 'Ya existe una solicitud de perfil profesional para este usuario';
    END IF;
    
    -- Verificar si el RUC ya está registrado
    IF EXISTS (SELECT 1 FROM professional_profiles WHERE ruc = p_ruc) THEN
        RAISE EXCEPTION 'Este RUC ya está registrado en el sistema';
    END IF;
    
    -- Crear registro de perfil profesional
    INSERT INTO professional_profiles (
        id,
        business_name,
        ruc,
        public_name,
        title,
        legal_document_url,
        status
    ) VALUES (
        p_profile_id,
        p_business_name,
        p_ruc,
        p_public_name,
        p_title,
        p_document_url,
        'pending'
    ) RETURNING id INTO v_account_id;
    
    -- Insertar el servicio base inicial usando la especialidad principal proporcionada
    IF p_specialty_id IS NOT NULL THEN
        INSERT INTO professional_services (
            professional_profile_id,
            professional_specialty_id,
            name,
            description,
            price,
            is_active
        ) VALUES (
            v_account_id,
            p_specialty_id,
            'Consulta Inicial',
            'Servicio base creado automáticamente al registrarse.',
            0.00,
            false -- Requiere que el profesional configure el precio luego
        );
    END IF;
    
    -- TODO: Enviar email de confirmación de solicitud
    -- (Implementar con Supabase Edge Functions o trigger)
    
    RETURN jsonb_build_object(
        'account_id', v_account_id,
        'status', 'pending'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HU-7.2: Catálogo Profesional
-- ============================================================================

-- RPC: Obtener productos Profesionales con validación de cuenta
CREATE OR REPLACE FUNCTION get_professional_products(p_profile_id BIGINT)
RETURNS TABLE (
    product_id BIGINT,
    name TEXT,
    sku TEXT,
    description TEXT,
    regular_price NUMERIC,
    professional_price NUMERIC,
    discount_pct NUMERIC,
    images TEXT[],
    weight_options JSONB,
    stock_quantity INTEGER
) AS $$
BEGIN
    -- Validar que usuario tenga cuenta Profesional aprobada
    IF NOT EXISTS (
        SELECT 1 FROM professional_profiles
        WHERE id = p_profile_id AND status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Usuario no tiene cuenta Profesional aprobada';
    END IF;
    
    -- Retornar productos con precios especiales
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.sku,
        p.description,
        p.price AS regular_price,
        ROUND(p.price * (1 - p.professional_discount_pct / 100.0), 2) AS professional_price,
        p.professional_discount_pct AS discount_pct,
        p.images,
        p.weight_options,
        p.stock_quantity
    FROM products p
    WHERE p.is_professional_product = TRUE 
      AND p.professional_discount_pct > 0
      AND p.status = 'active'
      AND p.is_active = TRUE
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Verificar elegibilidad Profesional de usuario
CREATE OR REPLACE FUNCTION check_professional_eligibility(p_profile_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
BEGIN
    -- Buscar cuenta del usuario
    SELECT * INTO v_account 
    FROM professional_profiles 
    WHERE id = p_profile_id;
    
    IF v_account IS NULL THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'status', 'not_registered'
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
            'status', 'pending'
        );
    ELSIF v_account.status = 'rejected' THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'status', 'rejected',
            'rejection_reason', v_account.rejection_reason
        );
    ELSE
        RETURN jsonb_build_object(
            'eligible', false,
            'status', v_account.status
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- Admin RPCs (para Gestión de Directorio Profesional)
-- ============================================================================

-- RPC: Aprobar cuenta Profesional
CREATE OR REPLACE FUNCTION approve_professional_account(
    p_account_id BIGINT,
    p_admin_profile_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
BEGIN
    -- Obtener cuenta
    SELECT * INTO v_account FROM professional_profiles WHERE id = p_account_id;
    
    IF v_account IS NULL THEN
        RAISE EXCEPTION 'Cuenta no encontrada';
    END IF;
    
    IF v_account.status != 'pending' THEN
        RAISE EXCEPTION 'Solo se pueden aprobar cuentas pendientes';
    END IF;
    
    -- Actualizar estado
    UPDATE professional_profiles
    SET status = 'approved',
        approved_by = p_admin_profile_id,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Asignar rol resolviendo su ID por nombre
    INSERT INTO profile_roles (profile_id, role_id)
    SELECT v_account.id, id FROM roles WHERE name = 'professional'
    ON CONFLICT (profile_id, role_id) DO NOTHING;
    
    -- TODO: Enviar email de aprobación al usuario
    -- (Implementar con Supabase Edge Functions)
    
    RETURN jsonb_build_object('account_id', p_account_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Rechazar cuenta Profesional
CREATE OR REPLACE FUNCTION reject_professional_account(
    p_account_id BIGINT,
    p_admin_profile_id BIGINT,
    p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
BEGIN
    -- Validar motivo
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'Debe proporcionar un motivo de rechazo';
    END IF;
    
    -- Obtener cuenta
    SELECT * INTO v_account FROM professional_profiles WHERE id = p_account_id;
    
    IF v_account IS NULL THEN
        RAISE EXCEPTION 'Cuenta no encontrada';
    END IF;
    
    IF v_account.status != 'pending' THEN
        RAISE EXCEPTION 'Solo se pueden rechazar cuentas pendientes';
    END IF;
    
    -- Actualizar estado
    UPDATE professional_profiles
    SET status = 'rejected',
        rejection_reason = p_reason,
        approved_by = p_admin_profile_id,  -- Registro de quién rechazó
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- TODO: Enviar email de rechazo con motivo
    -- (Implementar con Supabase Edge Functions)
    
    RETURN jsonb_build_object('account_id', p_account_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Suspender/Reactivar cuenta Profesional
CREATE OR REPLACE FUNCTION toggle_professional_account_status(
    p_account_id BIGINT,
    p_admin_profile_id BIGINT,
    p_suspend BOOLEAN
) RETURNS JSONB AS $$
DECLARE
    v_account RECORD;
    v_new_status VARCHAR;
BEGIN
    -- Obtener cuenta
    SELECT * INTO v_account FROM professional_profiles WHERE id = p_account_id;
    
    IF v_account IS NULL THEN
        RAISE EXCEPTION 'Cuenta no encontrada';
    END IF;
    
    -- Determinar nuevo estado
    IF p_suspend THEN
        IF v_account.status != 'approved' THEN
            RAISE EXCEPTION 'Solo se pueden suspender cuentas aprobadas';
        END IF;
        v_new_status := 'suspended';
    ELSE
        IF v_account.status != 'suspended' THEN
            RAISE EXCEPTION 'Solo se pueden reactivar cuentas suspendidas';
        END IF;
        v_new_status := 'approved';
    END IF;
    
    -- Actualizar estado
    UPDATE professional_profiles
    SET status = v_new_status,
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Actualizar rol del usuario resolviendo su ID por nombre
    IF v_new_status = 'approved' THEN
        INSERT INTO profile_roles (profile_id, role_id)
        SELECT v_account.id, id FROM roles WHERE name = 'professional'
        ON CONFLICT (profile_id, role_id) DO NOTHING;
    ELSE
        DELETE FROM profile_roles
        WHERE profile_id = v_account.id AND role_id = (SELECT id FROM roles WHERE name = 'professional');
    END IF;
    
    RETURN jsonb_build_object(
        'account_id', p_account_id,
        'new_status', v_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
