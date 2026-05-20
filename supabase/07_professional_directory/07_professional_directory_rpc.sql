-- ============================================================================
-- MassKot | Professional Directory Channel Module (07_professional_directory_rpc.sql)
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
    p_address_text TEXT,
    p_public_name TEXT,
    p_title TEXT,
    p_document_url TEXT,
    p_specialty_id INTEGER,
    p_latitude NUMERIC DEFAULT NULL,
    p_longitude NUMERIC DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_account_id BIGINT;
BEGIN
    -- Validar identidad de ejecución (Frontend security)
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado para crear perfil profesional para este usuario';
    END IF;

    -- Validar formato de RUC (11 dígitos)
    IF LENGTH(p_ruc) != 11 OR p_ruc !~ '^[0-9]+$' THEN
        RETURN jsonb_build_object(
            'success', false,
            'detail', 'RUC inválido: debe tener 11 dígitos numéricos'
        );
    END IF;
    
    -- Verificar si ya existe un perfil para este usuario
    IF EXISTS (SELECT 1 FROM professional_profiles WHERE profile_id = p_profile_id) THEN
        RAISE EXCEPTION 'Ya existe una solicitud de perfil profesional para este usuario';
    END IF;
    
    -- Verificar si el RUC ya está registrado
    IF EXISTS (SELECT 1 FROM professional_profiles WHERE ruc = p_ruc) THEN
        RAISE EXCEPTION 'Este RUC ya está registrado en el sistema';
    END IF;
    
    -- Crear registro de perfil profesional
    INSERT INTO professional_profiles (
        profile_id,
        business_name,
        ruc,
        address_text,
        latitude,
        longitude,
        public_name,
        title,
        legal_document_url,
        status
    ) VALUES (
        p_profile_id,
        p_business_name,
        p_ruc,
        p_address_text,
        p_latitude,
        p_longitude,
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

-- RPC: Listar profesionales publicados con filtros
CREATE OR REPLACE FUNCTION get_published_professionals(
    p_specialty_id INTEGER DEFAULT NULL,
    p_consultation_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_location TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'rating'
)
RETURNS TABLE (
    id BIGINT,
    public_name TEXT,
    title TEXT,
    profile_photo_url TEXT,
    address_text TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    base_price NUMERIC,
    consultation_types TEXT[],
    average_rating NUMERIC,
    total_reviews INTEGER,
    specialty_name TEXT,
    specialty_slug TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.public_name,
        p.title,
        p.profile_photo_url,
        p.address_text,
        p.latitude,
        p.longitude,
        p.base_price,
        p.consultation_types,
        COALESCE(p.average_rating, 0),
        COALESCE(p.total_reviews, 0),
        sp.name,
        sp.slug
    FROM professional_profiles p
    JOIN professional_services ps
        ON ps.professional_profile_id = p.id
    JOIN professional_specialties sp
        ON sp.id = ps.professional_specialty_id
    WHERE p.status = 'approved'
            AND p.is_published = true
      AND (p_specialty_id IS NULL OR ps.professional_specialty_id = p_specialty_id)
      AND (p_consultation_type IS NULL OR p.consultation_types @> ARRAY[p_consultation_type])
      AND (p_search IS NULL OR p.public_name ILIKE CONCAT('%', p_search, '%'))
      AND (p_location IS NULL OR p.address_text ILIKE CONCAT('%', p_location, '%'))
    ORDER BY
      CASE WHEN p_sort_by = 'rating' THEN p.average_rating END DESC,
      CASE WHEN p_sort_by = 'price_asc' THEN p.base_price END ASC,
      CASE WHEN p_sort_by = 'price_desc' THEN p.base_price END DESC,
      CASE WHEN p_sort_by = 'name' THEN p.public_name END ASC,
      p.id DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Listar todos los profesionales (admin)
CREATE OR REPLACE FUNCTION get_all_professionals()
RETURNS TABLE (
    id BIGINT,
    profile_id BIGINT,
    public_name TEXT,
    business_name TEXT,
    title TEXT,
    ruc TEXT,
    profile_photo_url TEXT,
    address_text TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    base_price NUMERIC,
    consultation_types TEXT[],
    average_rating NUMERIC,
    total_reviews INTEGER,
    status TEXT,
    is_published BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    IF NOT auth_has_role('admin') THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol de administrador';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.profile_id,
        p.public_name,
        p.business_name,
        p.title,
        p.ruc,
        p.profile_photo_url,
        p.address_text,
        p.latitude,
        p.longitude,
        p.base_price,
        p.consultation_types,
        COALESCE(p.average_rating, 0),
        COALESCE(p.total_reviews, 0),
        p.status::text,
        COALESCE(p.is_published, false),
        p.created_at,
        p.updated_at
    FROM professional_profiles p
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    -- Validar identidad de ejecución (solo el profesional dueño puede acceder a sus precios B2B)
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado para acceder a este catálogo profesional';
    END IF;

    -- Validar que usuario tenga cuenta Profesional aprobada
    IF NOT EXISTS (
        SELECT 1 FROM professional_profiles
        WHERE profile_id = p_profile_id AND status = 'approved'
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
    -- Validar identidad de ejecución (Frontend security)
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado para verificar elegibilidad de este perfil';
    END IF;

    -- Buscar cuenta del usuario
    SELECT * INTO v_account 
    FROM professional_profiles 
    WHERE profile_id = p_profile_id;
    
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    -- Validar rol de administrador
    IF NOT auth_has_role('admin') THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol de administrador';
    END IF;

    -- Obtener cuenta
    SELECT * INTO v_account
    FROM professional_profiles
    WHERE id = p_account_id;
    
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
        is_published = true,
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Asignar rol resolviendo su ID por nombre
    INSERT INTO profile_roles (profile_id, role_id)
    SELECT v_account.profile_id, id FROM roles WHERE name = 'professional'
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
    -- Validar rol de administrador
    IF NOT auth_has_role('admin') THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol de administrador';
    END IF;

    -- Validar motivo
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'Debe proporcionar un motivo de rechazo';
    END IF;
    
    -- Obtener cuenta
    SELECT * INTO v_account
    FROM professional_profiles
    WHERE id = p_account_id;
    
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
    -- Validar rol de administrador
    IF NOT auth_has_role('admin') THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol de administrador';
    END IF;

    -- Obtener cuenta
    SELECT * INTO v_account
    FROM professional_profiles
    WHERE id = p_account_id;
    
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
        SELECT v_account.profile_id, id FROM roles WHERE name = 'professional'
        ON CONFLICT (profile_id, role_id) DO NOTHING;
    ELSE
        DELETE FROM profile_roles
        WHERE profile_id = v_account.profile_id AND role_id = (SELECT id FROM roles WHERE name = 'professional');
    END IF;
    
    RETURN jsonb_build_object(
        'account_id', p_account_id,
        'new_status', v_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
