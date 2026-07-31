-- ============================================================================
-- MassKot | Professional Directory Public RPCs
-- For listing published professionals and detail view
--
-- ACTUALIZADO: 2026-06-02 para modelo Doctoralia-style v2
-- Las funciones marked "LEGACY" usan las tablas old y deben migrarse al nuevo modelo.
-- ============================================================================

-- ============================================================================
-- RPC: Get published professionals list (for SpecialistsShowcasePage)
-- ACTUALIZADO: Incluye direcciones del modelo v2 (professional_addresses)
-- ============================================================================
-- Nota: Postgres no permite cambiar el RETURNS TABLE con CREATE OR REPLACE.
-- Por eso dropeamos primero la función existente (misma firma de parámetros).
DROP FUNCTION IF EXISTS get_public_professionals(BIGINT, TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION get_public_professionals(
    p_specialty_id BIGINT DEFAULT NULL,
    p_consultation_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_location TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'rating'
) RETURNS TABLE (
    id BIGINT,
    slug TEXT,
    public_name TEXT,
    title TEXT,
    profile_photo_url TEXT,
    base_price NUMERIC,
    consultation_types TEXT[],
    average_rating NUMERIC,
    total_reviews INTEGER,
    specialty_name TEXT,
    specialty_slug TEXT,
    is_published BOOLEAN,
    experience_summary TEXT,
    is_available BOOLEAN,
    phone TEXT,
    -- Nuevos campos del modelo v2
    primary_address_id BIGINT,
    primary_address_name TEXT,
    primary_address_line TEXT,
    primary_address_district TEXT,
    primary_address_province TEXT,
    primary_address_latitude NUMERIC,
    primary_address_longitude NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (p.id)
        p.id,
        p.slug,
        p.public_name,
        p.title,
        p.profile_photo_url,
        p.base_price,
        p.consultation_types,
        COALESCE(p.average_rating, 0) as average_rating,
        COALESCE(p.total_reviews, 0) as total_reviews,
        sp.name as specialty_name,
        sp.slug as specialty_slug,
        p.is_published,
        p.experience_summary,
        COALESCE(p.is_available, true) as is_available,
        p.phone,
        -- Nueva info de dirección del modelo v2
        pa.id as primary_address_id,
        pa.name as primary_address_name,
        pa.address_line as primary_address_line,
        pa.district as primary_address_district,
        pa.province as primary_address_province,
        pa.latitude as primary_address_latitude,
        pa.longitude as primary_address_longitude
    FROM professional_profiles p
    LEFT JOIN professional_services ps ON ps.professional_profile_id = p.id
    LEFT JOIN professional_specialties sp ON sp.id = ps.professional_specialty_id
    LEFT JOIN professional_addresses pa ON pa.professional_profile_id = p.id AND pa.is_primary = true AND pa.is_active = true
    WHERE p.status = 'approved'
        AND p.is_published = true
        AND (p_specialty_id IS NULL OR ps.professional_specialty_id = p_specialty_id)
        AND (p_consultation_type IS NULL OR p.consultation_types @> ARRAY[p_consultation_type])
        AND (p_search IS NULL OR p.public_name ILIKE CONCAT('%', p_search, '%'))
        -- Búsqueda por ubicación ahora usa district/province del modelo v2
        AND (
            p_location IS NULL OR
            pa.district ILIKE CONCAT('%', p_location, '%') OR
            pa.province ILIKE CONCAT('%', p_location, '%') OR
            pa.address_line ILIKE CONCAT('%', p_location, '%')
        )
    ORDER BY p.id,
        CASE WHEN p_sort_by = 'rating' THEN p.average_rating END DESC,
        CASE WHEN p_sort_by = 'price_asc' THEN p.base_price END ASC,
        CASE WHEN p_sort_by = 'price_desc' THEN p.base_price END DESC,
        CASE WHEN p_sort_by = 'name' THEN p.public_name END ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Nota: Postgres no permite renombrar parámetros con CREATE OR REPLACE.
-- Por eso dropeamos primero la función existente (misma firma de tipos).
DROP FUNCTION IF EXISTS get_professional_public_detail(TEXT);
DROP FUNCTION IF EXISTS get_professional_public_detail(BIGINT);
CREATE OR REPLACE FUNCTION get_professional_public_detail(
    p_professional_id TEXT
) RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
    v_services JSONB;
    v_addresses JSONB;
    v_availability JSONB;
    v_reviews JSONB;
    v_profile_json JSONB;
    v_id BIGINT;
BEGIN
    -- Primero intentamos buscar por ID (si es numérico)
    v_id := NULL;
    IF p_professional_id ~ '^[0-9]+$' THEN
        v_id := p_professional_id::BIGINT;
    END IF;

    IF v_id IS NOT NULL THEN
        SELECT * INTO v_profile
        FROM professional_profiles
        WHERE id = v_id
            AND status = 'approved'
            AND is_published = true;
    END IF;

    -- Si no se encontró por ID, intentamos por slug
    IF v_profile IS NULL THEN
        SELECT * INTO v_profile
        FROM professional_profiles
        WHERE slug = p_professional_id
            AND status = 'approved'
            AND is_published = true;
    END IF;

    IF v_profile IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Profesional no encontrado');
    END IF;

    -- Convertir perfil a JSONB para acceder de forma segura a campos opcionales
    v_profile_json := to_jsonb(v_profile);

    -- Obtener servicios activos
    SELECT jsonb_agg(jsonb_build_object(
        'id', ps.id,
        'name', ps.name,
        'description', ps.description,
        'price', ps.price,
        'specialty_name', sp.name
    ) ORDER BY ps.is_active DESC) INTO v_services
    FROM professional_services ps
    JOIN professional_specialties sp ON sp.id = ps.professional_specialty_id
    WHERE ps.professional_profile_id = v_profile.id
        AND ps.is_active = true;

    -- Obtener direcciones del modelo v2
    SELECT jsonb_agg(jsonb_build_object(
        'id', pa.id,
        'name', pa.name,
        'address_line', pa.address_line,
        'reference', pa.reference,
        'district', pa.district,
        'province', pa.province,
        'latitude', pa.latitude,
        'longitude', pa.longitude,
        'phone', pa.phone,
        'address_type', pa.address_type,
        'custom_price', pa.custom_price,
        'is_primary', pa.is_primary
    ) ORDER BY pa.is_primary DESC, pa.id) INTO v_addresses
    FROM professional_addresses pa
    WHERE pa.professional_profile_id = v_profile.id AND pa.is_active = true;

    -- Obtener disponibilidad del modelo v2 (proximos 30 días)
    SELECT jsonb_agg(jsonb_build_object(
        'id', paa.id,
        'address_id', paa.professional_address_id,
        'address_name', pa.name,
        'date', paa.availability_date,
        'start_time', paa.start_time,
        'end_time', paa.end_time,
        'available_slots', paa.available_slots
    ) ORDER BY paa.availability_date) INTO v_availability
    FROM professional_address_availability paa
    JOIN professional_addresses pa ON pa.id = paa.professional_address_id
    WHERE pa.professional_profile_id = v_profile.id
        AND paa.is_active = true
        AND paa.availability_date >= CURRENT_DATE
        AND paa.availability_date <= CURRENT_DATE + INTERVAL '30 days';

    -- Obtener reseñas
    SELECT jsonb_agg(jsonb_build_object(
        'id', pr.id,
        'reviewer_name', COALESCE(prof.full_name, 'Cliente verificado'),
        'rating', pr.rating,
        'comment', pr.comment,
        'professional_response', pr.professional_response,
        'responded_at', pr.responded_at,
        'created_at', pr.created_at
    ) ORDER BY pr.created_at DESC) INTO v_reviews
    FROM professional_reviews pr
    LEFT JOIN profiles prof ON prof.id = pr.client_profile_id
    WHERE pr.professional_profile_id = v_profile.id
    LIMIT 10;

    RETURN jsonb_build_object(
        'success', true,
        'profile', jsonb_build_object(
            'id', v_profile.id,
            'slug', v_profile.slug,
            'public_name', v_profile.public_name,
            'title', v_profile.title,
            'profile_photo_url', v_profile.profile_photo_url,
            'experience_summary', COALESCE(v_profile_json->>'experience_summary', ''),
            'consultation_types', COALESCE(v_profile_json->'consultation_types', '[]'::jsonb),
            'treated_conditions', COALESCE(v_profile.treated_conditions, ''),
            'gallery_urls', COALESCE(v_profile_json->'gallery_urls', '[]'::jsonb),
            'average_rating', COALESCE(v_profile.average_rating, 0),
            'total_reviews', COALESCE(v_profile.total_reviews, 0),
            'is_available', COALESCE(v_profile.is_available, true),
            'phone', v_profile.phone,
            'base_price', v_profile.base_price
        ),
        'services', COALESCE(v_services, '[]'::jsonb),
        'addresses', COALESCE(v_addresses, '[]'::jsonb),
        'availability', COALESCE(v_availability, '[]'::jsonb),
        'reviews', COALESCE(v_reviews, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Create appointment booking (LEGACY - modelo antiguo)
-- NOTA: Esta función usa professional_appointments (legacy).
-- Para el nuevo modelo usar: create_appointment_request (en 01_update_sql_professional_part1_rpc.sql)
-- ============================================================================
CREATE OR REPLACE FUNCTION create_professional_appointment(
    p_professional_id BIGINT,
    p_client_profile_id BIGINT,
    p_appointment_date DATE,
    p_start_time TIME,
    p_end_time TIME,
    p_service_id BIGINT DEFAULT NULL,
    p_is_first_visit BOOLEAN DEFAULT true
) RETURNS JSONB AS $$
DECLARE
    v_appointment_id BIGINT;
    v_professional_id_check BIGINT;
BEGIN
    -- Validar que el profesional existe y está publicado
    SELECT id INTO v_professional_id_check
    FROM professional_profiles
    WHERE id = p_professional_id
        AND status = 'approved'
        AND is_published = true;

    IF v_professional_id_check IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Profesional no disponible');
    END IF;

    -- Verificar que no existe un appointment en el mismo horario
    IF EXISTS (
        SELECT 1 FROM professional_appointments
        WHERE professional_profile_id = p_professional_id
            AND appointment_date = p_appointment_date
            AND (
                (start_time <= p_start_time AND end_time > p_start_time)
                OR (start_time < p_end_time AND end_time >= p_end_time)
                OR (start_time >= p_start_time AND end_time <= p_end_time)
            )
            AND status NOT IN ('cancelled', 'no_show')
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Este horario ya no está disponible');
    END IF;

    -- Crear la cita
    INSERT INTO professional_appointments (
        professional_profile_id,
        client_profile_id,
        service_id,
        appointment_date,
        start_time,
        end_time,
        is_first_visit,
        status
    ) VALUES (
        p_professional_id,
        p_client_profile_id,
        p_service_id,
        p_appointment_date,
        p_start_time,
        p_end_time,
        p_is_first_visit,
        'pending'
    ) RETURNING id INTO v_appointment_id;

    RETURN jsonb_build_object(
        'success', true,
        'appointment_id', v_appointment_id,
        'message', 'Cita creada exitosamente. El profesional confirmará pronto.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Get professional availability slots for a specific date
-- NOTA: Esta función es LEGACY. Para el nuevo modelo usar get_address_day_slots
-- ============================================================================
CREATE OR REPLACE FUNCTION get_professional_day_slots(
    p_professional_id BIGINT,
    p_date DATE
) RETURNS JSONB AS $$
DECLARE
    v_day_of_week INTEGER;
    v_availability JSONB;
    v_booked_slots JSONB;
    v_result JSONB := '[]'::jsonb;
    v_slot JSONB;
BEGIN
    -- Obtener día de la semana (0=Domingo, 1=Lunes, etc.)
    v_day_of_week := EXTRACT(DOW FROM p_date)::INTEGER;

    -- Obtener configuración de disponibilidad para ese día
    SELECT jsonb_agg(jsonb_build_object(
        'start_time', pa.start_time,
        'end_time', pa.end_time
    ) ORDER BY pa.start_time) INTO v_availability
    FROM professional_availability pa
    WHERE pa.professional_profile_id = p_professional_id
        AND pa.day_of_week = v_day_of_week
        AND pa.is_active = true;

    -- Obtener citas ya reservadas para ese día
    SELECT jsonb_agg(jsonb_build_object(
        'start_time', start_time,
        'end_time', end_time
    )) INTO v_booked_slots
    FROM professional_appointments
    WHERE professional_profile_id = p_professional_id
        AND appointment_date = p_date
        AND status NOT IN ('cancelled', 'no_show');

    -- Generar slots de 30 minutos
    IF v_availability IS NOT NULL THEN
        FOR v_slot IN SELECT * FROM jsonb_array_elements(v_availability)
        LOOP
            -- Generar slots de 30 minutos dentro del rango
            v_result := v_result || jsonb_build_array(jsonb_build_object(
                'start_time', v_slot->>'start_time',
                'end_time', v_slot->>'end_time',
                'is_available', true
            ));
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'availability', COALESCE(v_availability, '[]'::jsonb),
        'booked', COALESCE(v_booked_slots, '[]'::jsonb),
        'slots', v_result
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Get professional public detail - NUEVO MODELO v2
-- Esta función es la versión nueva que incluye toda la info del modelo v2
-- ============================================================================
DROP FUNCTION IF EXISTS get_professional_public_detail_v2(TEXT);
CREATE OR REPLACE FUNCTION get_professional_public_detail_v2(
    p_professional_id TEXT
) RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
    v_services JSONB;
    v_addresses JSONB;
    v_reviews JSONB;
    v_availability JSONB;
    v_faqs JSONB;
    v_profile_json JSONB;
    v_id BIGINT;
BEGIN
    -- Primero intentamos buscar por ID (si es numérico)
    v_id := NULL;
    IF p_professional_id ~ '^[0-9]+$' THEN
        v_id := p_professional_id::BIGINT;
    END IF;

    IF v_id IS NOT NULL THEN
        SELECT * INTO v_profile
        FROM professional_profiles
        WHERE id = v_id
            AND status = 'approved'
            AND is_published = true;
    END IF;

    -- Si no se encontró por ID, intentamos por slug
    IF v_profile IS NULL THEN
        SELECT * INTO v_profile
        FROM professional_profiles
        WHERE slug = p_professional_id
            AND status = 'approved'
            AND is_published = true;
    END IF;

    IF v_profile IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Profesional no encontrado');
    END IF;

    -- Convertir perfil a JSONB para acceder de forma segura a campos opcionales
    v_profile_json := to_jsonb(v_profile);

    -- Obtener servicios activos
    SELECT jsonb_agg(jsonb_build_object(
        'id', ps.id,
        'name', ps.name,
        'description', ps.description,
        'price', ps.price,
        'specialty_name', sp.name,
        'address_ids', (
            SELECT COALESCE(jsonb_agg(pas.professional_address_id), '[]'::jsonb)
            FROM professional_address_services pas
            WHERE pas.professional_service_id = ps.id AND pas.is_active = true
        )
    ) ORDER BY ps.is_active DESC) INTO v_services
    FROM professional_services ps
    JOIN professional_specialties sp ON sp.id = ps.professional_specialty_id
    WHERE ps.professional_profile_id = v_profile.id AND ps.is_active = true;

    -- Obtener direcciones activas del modelo v2
    SELECT jsonb_agg(jsonb_build_object(
        'id', pa.id,
        'name', pa.name,
        'address_line', pa.address_line,
        'reference', pa.reference,
        'district', pa.district,
        'province', pa.province,
        'latitude', pa.latitude,
        'longitude', pa.longitude,
        'phone', pa.phone,
        'address_type', pa.address_type,
        'custom_price', pa.custom_price,
        'is_primary', pa.is_primary
    ) ORDER BY pa.is_primary DESC, pa.id) INTO v_addresses
    FROM professional_addresses pa
    WHERE pa.professional_profile_id = v_profile.id AND pa.is_active = true;

    -- Obtener reseñas
    SELECT jsonb_agg(jsonb_build_object(
        'id', pr.id,
        'reviewer_name', COALESCE(prof.full_name, 'Cliente verificado'),
        'rating', pr.rating,
        'comment', pr.comment,
        'professional_response', pr.professional_response,
        'responded_at', pr.responded_at,
        'created_at', pr.created_at
    ) ORDER BY pr.created_at DESC) INTO v_reviews
    FROM professional_reviews pr
    LEFT JOIN profiles prof ON prof.id = pr.client_profile_id
    WHERE pr.professional_profile_id = v_profile.id
    LIMIT 10;

    -- Obtener disponibilidad del modelo v2 (proximos 30 días)
    SELECT jsonb_agg(jsonb_build_object(
        'id', paa.id,
        'address_id', paa.professional_address_id,
        'address_name', pa.name,
        'date', paa.availability_date,
        'start_time', paa.start_time,
        'end_time', paa.end_time,
        'available_slots', paa.available_slots,
        'notes', paa.notes
    ) ORDER BY paa.availability_date) INTO v_availability
    FROM professional_address_availability paa
    JOIN professional_addresses pa ON pa.id = paa.professional_address_id
    WHERE pa.professional_profile_id = v_profile.id
        AND paa.is_active = true
        AND paa.availability_date >= CURRENT_DATE
        AND paa.availability_date <= CURRENT_DATE + INTERVAL '30 days';

    -- Obtener FAQs activas públicas
    SELECT jsonb_agg(jsonb_build_object(
        'id', pf.id,
        'question', pf.question,
        'answer', pf.answer,
        'display_order', pf.display_order,
        'is_active', pf.is_active
    ) ORDER BY pf.display_order, pf.id) INTO v_faqs
    FROM professional_faqs pf
    WHERE pf.professional_profile_id = v_profile.id
      AND pf.is_active = true;

    RETURN jsonb_build_object(
        'success', true,
        'profile', jsonb_build_object(
            'id', v_profile.id,
            'slug', v_profile.slug,
            'public_name', v_profile.public_name,
            'title', v_profile.title,
            'profile_photo_url', v_profile.profile_photo_url,
            'experience_summary', COALESCE(v_profile_json->>'experience_summary', ''),
            'consultation_types', COALESCE(v_profile_json->'consultation_types', '[]'::jsonb),
            'treated_conditions', COALESCE(v_profile.treated_conditions, ''),
            'gallery_urls', COALESCE(v_profile_json->'gallery_urls', '[]'::jsonb),
            'average_rating', COALESCE(v_profile.average_rating, 0),
            'total_reviews', COALESCE(v_profile.total_reviews, 0),
            'is_available', COALESCE(v_profile.is_available, true),
            'phone', v_profile.phone,
            'base_price', v_profile.base_price
        ),
        'services', COALESCE(v_services, '[]'::jsonb),
        'addresses', COALESCE(v_addresses, '[]'::jsonb),
        'reviews', COALESCE(v_reviews, '[]'::jsonb),
        'availability', COALESCE(v_availability, '[]'::jsonb),
        'faqs', COALESCE(v_faqs, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;