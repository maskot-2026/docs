-- ============================================================================
-- MassKot | Professional Directory Public RPCs
-- For listing published professionals and detail view
-- ============================================================================

-- ============================================================================
-- RPC: Get published professionals list (for SpecialistsShowcasePage)
-- Incluye: slug, is_available, phone para SEO y contacto
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
    address_text TEXT,
    base_price NUMERIC,
    consultation_types TEXT[],
    average_rating NUMERIC,
    total_reviews INTEGER,
    specialty_name TEXT,
    specialty_slug TEXT,
    is_published BOOLEAN,
    experience_summary TEXT,
    is_available BOOLEAN,
    phone TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (p.id)
        p.id,
        p.slug,
        p.public_name,
        p.title,
        p.profile_photo_url,
        p.address_text,
        p.base_price,
        p.consultation_types,
        COALESCE(p.average_rating, 0) as average_rating,
        COALESCE(p.total_reviews, 0) as total_reviews,
        sp.name as specialty_name,
        sp.slug as specialty_slug,
        p.is_published,
        p.experience_summary,
        COALESCE(p.is_available, true) as is_available,
        p.phone
    FROM professional_profiles p
    LEFT JOIN professional_services ps ON ps.professional_profile_id = p.id
    LEFT JOIN professional_specialties sp ON sp.id = ps.professional_specialty_id
    WHERE p.status = 'approved'
        AND p.is_published = true
        AND (p_specialty_id IS NULL OR ps.professional_specialty_id = p_specialty_id)
        AND (p_consultation_type IS NULL OR p.consultation_types @> ARRAY[p_consultation_type])
        AND (p_search IS NULL OR p.public_name ILIKE CONCAT('%', p_search, '%'))
        AND (p_location IS NULL OR p.address_text ILIKE CONCAT('%', p_location, '%'))
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
    )) INTO v_services
    FROM professional_services ps
    JOIN professional_specialties sp ON sp.id = ps.professional_specialty_id
    WHERE ps.professional_profile_id = v_profile.id
        AND ps.is_active = true;

    -- Obtener disponibilidad activa (días disponibles)
    SELECT jsonb_agg(jsonb_build_object(
        'id', pa.id,
        'day_of_week', pa.day_of_week,
        'start_time', pa.start_time,
        'end_time', pa.end_time
    ) ORDER BY pa.day_of_week, pa.start_time) INTO v_availability
    FROM professional_availability pa
    WHERE pa.professional_profile_id = v_profile.id
        AND pa.is_active = true;

    -- Obtener reseñas
    SELECT jsonb_agg(jsonb_build_object(
        'id', pr.id,
        'reviewer_name', COALESCE(p.full_name, 'Cliente verificado'),
        'rating', pr.rating,
        'comment', pr.comment,
        'created_at', pr.created_at
    ) ORDER BY pr.created_at DESC) INTO v_reviews
    FROM professional_reviews pr
    LEFT JOIN profiles p ON p.id = pr.client_profile_id
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
            'address_text', v_profile.address_text,
            'base_price', v_profile.base_price,
            'consultation_types', COALESCE(v_profile_json->'consultation_types', '[]'::jsonb),
            'experience_summary', COALESCE(v_profile_json->>'experience_summary', ''),
            'treated_conditions', COALESCE(v_profile_json->'treated_conditions', '[]'::jsonb),
            'gallery_urls', COALESCE(v_profile_json->'gallery_urls', '[]'::jsonb),
            'average_rating', COALESCE(v_profile.average_rating, 0),
            'total_reviews', COALESCE(v_profile.total_reviews, 0),
            'is_available', COALESCE(v_profile.is_available, true),
            'phone', v_profile.phone
        ),
        'services', COALESCE(v_services, '[]'::jsonb),
        'availability', COALESCE(v_availability, '[]'::jsonb),
        'reviews', COALESCE(v_reviews, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Create appointment booking (para BookingWidget legacy)
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
