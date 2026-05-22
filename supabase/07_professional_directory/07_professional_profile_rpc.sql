-- ============================================================================
-- MassKot | Professional Profile Management RPCs
-- RPC Implementations for Professional Profile, Services, and Availability
-- ============================================================================

-- ============================================================================
-- RPC: Get full professional profile with services and availability
-- ============================================================================
CREATE OR REPLACE FUNCTION get_professional_full_profile(
    p_profile_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
    v_services JSONB;
    v_availability JSONB;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    -- Obtener perfil profesional
    SELECT * INTO v_profile FROM professional_profiles WHERE profile_id = p_profile_id;

    IF v_profile IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Obtener servicios
    SELECT jsonb_agg(row_to_json(s)) INTO v_services
    FROM (
        SELECT ps.id, ps.name, ps.description, ps.price, ps.is_active,
               sp.name as specialty_name, sp.id as specialty_id
        FROM professional_services ps
        JOIN professional_specialties sp ON sp.id = ps.professional_specialty_id
        WHERE ps.professional_profile_id = v_profile.id
        ORDER BY ps.is_active DESC, ps.id
    ) s;

    -- Obtener disponibilidad
    SELECT jsonb_agg(row_to_json(a) ORDER BY a.day_of_week, a.start_time) INTO v_availability
    FROM (
        SELECT pa.id, pa.day_of_week, pa.start_time, pa.end_time, pa.is_active
        FROM professional_availability pa
        WHERE pa.professional_profile_id = v_profile.id
    ) a;

    RETURN jsonb_build_object(
        'success', true,
        'profile', row_to_json(v_profile),
        'services', COALESCE(v_services, '[]'::jsonb),
        'availability', COALESCE(v_availability, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Update professional profile basic info
-- ============================================================================
CREATE OR REPLACE FUNCTION update_professional_profile(
    p_profile_id BIGINT,
    p_public_name TEXT DEFAULT NULL,
    p_title TEXT DEFAULT NULL,
    p_experience_summary TEXT DEFAULT NULL,
    p_base_price NUMERIC DEFAULT NULL,
    p_consultation_types TEXT[] DEFAULT NULL,
    p_address_text TEXT DEFAULT NULL,
    p_profile_photo_url TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_profile_id BIGINT;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_profile_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_profile_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Actualizar solo los campos proporcionados
    UPDATE professional_profiles SET
        public_name = COALESCE(p_public_name, public_name),
        title = COALESCE(p_title, title),
        experience_summary = COALESCE(p_experience_summary, experience_summary),
        base_price = COALESCE(p_base_price, base_price),
        consultation_types = COALESCE(p_consultation_types, consultation_types),
        address_text = COALESCE(p_address_text, address_text),
        profile_photo_url = COALESCE(p_profile_photo_url, profile_photo_url),
        updated_at = NOW()
    WHERE profile_id = p_profile_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Add or update a professional service
-- ============================================================================
CREATE OR REPLACE FUNCTION upsert_professional_service(
    p_profile_id BIGINT,
    p_specialty_id BIGINT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_price NUMERIC DEFAULT 0,
    p_is_active BOOLEAN DEFAULT true,
    p_service_id BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_service_id BIGINT;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    IF p_service_id IS NOT NULL THEN
        -- Actualizar servicio existente
        UPDATE professional_services SET
            professional_specialty_id = p_specialty_id,
            name = p_name,
            description = p_description,
            price = p_price,
            is_active = p_is_active
        WHERE id = p_service_id AND professional_profile_id = v_professional_id
        RETURNING id INTO v_service_id;
    ELSE
        -- Crear nuevo servicio
        INSERT INTO professional_services (
            professional_profile_id, professional_specialty_id, name, description, price, is_active
        ) VALUES (
            v_professional_id, p_specialty_id, p_name, p_description, p_price, p_is_active
        ) RETURNING id INTO v_service_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'service_id', v_service_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Deactivate a professional service
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_professional_service(
    p_profile_id BIGINT,
    p_service_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

        UPDATE professional_services
        SET is_active = false,
            updated_at = NOW()
        WHERE id = p_service_id AND professional_profile_id = v_professional_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Set professional availability (update existing, insert new, deactivate missing)
-- ============================================================================
CREATE OR REPLACE FUNCTION set_professional_availability(
    p_profile_id BIGINT,
    p_slots JSONB
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_slot JSONB;
    v_slot_id BIGINT;
    v_slot_ids BIGINT[] := '{}'::BIGINT[];
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Actualizar o insertar disponibilidad
    FOR v_slot IN SELECT * FROM jsonb_array_elements(p_slots)
    LOOP
        v_slot_id := NULLIF(v_slot->>'id', '')::BIGINT;

        IF v_slot_id IS NOT NULL THEN
            UPDATE professional_availability
            SET day_of_week = (v_slot->>'day_of_week')::INT,
                start_time = (v_slot->>'start_time')::TIME,
                end_time = (v_slot->>'end_time')::TIME,
                is_active = COALESCE((v_slot->>'is_active')::BOOLEAN, true),
                updated_at = NOW()
            WHERE id = v_slot_id
              AND professional_profile_id = v_professional_id;

            v_slot_ids := array_append(v_slot_ids, v_slot_id);
        ELSE
            INSERT INTO professional_availability (
                professional_profile_id, day_of_week, start_time, end_time, is_active
            ) VALUES (
                v_professional_id,
                (v_slot->>'day_of_week')::INT,
                (v_slot->>'start_time')::TIME,
                (v_slot->>'end_time')::TIME,
                COALESCE((v_slot->>'is_active')::BOOLEAN, true)
            ) RETURNING id INTO v_slot_id;

            v_slot_ids := array_append(v_slot_ids, v_slot_id);
        END IF;
    END LOOP;

    -- Desactivar slots que ya no vienen en el payload
    UPDATE professional_availability
    SET is_active = false,
        updated_at = NOW()
    WHERE professional_profile_id = v_professional_id
      AND (array_length(v_slot_ids, 1) IS NULL OR id <> ALL (v_slot_ids));

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: Toggle professional publication status
-- ============================================================================
CREATE OR REPLACE FUNCTION toggle_professional_publication(
    p_profile_id BIGINT,
    p_publish BOOLEAN DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_status TEXT;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    -- Si p_publish es NULL, alternar
    IF p_publish IS NULL THEN
        SELECT CASE WHEN is_published THEN false ELSE true END INTO p_publish
        FROM professional_profiles WHERE profile_id = p_profile_id;
    END IF;

    UPDATE professional_profiles SET
        is_published = p_publish,
        updated_at = NOW()
    WHERE profile_id = p_profile_id;

    RETURN jsonb_build_object('success', true, 'is_published', p_publish);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
