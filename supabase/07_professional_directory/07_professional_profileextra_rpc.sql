-- ============================================================================
-- MassKot | Professional Directory RPCs - Modelo Doctoralia-style v2
-- 01_update_sql_professional_part1_rpc.sql
--
-- RPCs para el nuevo modelo de:
-- - Direcciones múltiples (professional_addresses)
-- - Disponibilidad por fecha (professional_address_availability)
-- - Solicitudes de cita (professional_appointment_requests)
-- - Reviews vinculadas a solicitudes (professional_reviews)
--
-- NOTA: Los RPCs del modelo LEGACY (professional_availability,
-- professional_appointments) siguen en:
-- - 07_professional_profile_rpc.sql (set_professional_availability, etc.)
-- - 07_professional_public_rpc.sql (create_professional_appointment, etc.)
--
-- Este archivo implementa el modelo v2 que el frontend NUEVO usará.
-- ============================================================================


-- ============================================================================
-- 1. DIRECCIONES DEL PROFESIONAL (professional_addresses)
-- ============================================================================

-- RPC: Obtener todas las direcciones de un profesional
CREATE OR REPLACE FUNCTION get_professional_addresses(
    p_profile_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_addresses JSONB;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    SELECT jsonb_agg(jsonb_build_object(
        'id', pa.id,
        'name', pa.name,
        'address_line', pa.address_line,
        'reference', pa.reference,
        'district', pa.district,
        'province', pa.province,
        'department', pa.department,
        'latitude', pa.latitude,
        'longitude', pa.longitude,
        'phone', pa.phone,
        'address_type', pa.address_type,
        'custom_price', pa.custom_price,
        'is_primary', pa.is_primary,
        'is_active', pa.is_active,
        'created_at', pa.created_at
    ) ORDER BY pa.is_primary DESC, pa.id) INTO v_addresses
    FROM professional_addresses pa
    WHERE pa.professional_profile_id = v_professional_id;

    RETURN jsonb_build_object(
        'success', true,
        'addresses', COALESCE(v_addresses, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear o actualizar dirección del profesional
CREATE OR REPLACE FUNCTION upsert_professional_address(
    p_profile_id BIGINT,
    p_address_id BIGINT DEFAULT NULL,
    p_name TEXT DEFAULT 'Consultorio principal',
    p_address_line TEXT DEFAULT NULL,
    p_reference TEXT DEFAULT NULL,
    p_district TEXT DEFAULT 'Lima',
    p_province TEXT DEFAULT 'Lima',
    p_department TEXT DEFAULT 'Lima',
    p_latitude NUMERIC DEFAULT NULL,
    p_longitude NUMERIC DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_address_type TEXT DEFAULT 'physical',
    p_custom_price NUMERIC DEFAULT NULL,
    p_is_primary BOOLEAN DEFAULT false,
    p_is_active BOOLEAN DEFAULT true
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_address_id BIGINT;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Validar dirección requerida
    IF p_address_line IS NULL OR p_address_line = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dirección es requerida');
    END IF;

    -- Si es primary, desmarcar otras direcciones primary
    IF p_is_primary THEN
        UPDATE professional_addresses
        SET is_primary = false, updated_at = NOW()
        WHERE professional_profile_id = v_professional_id AND is_primary = true;
    END IF;

    IF p_address_id IS NOT NULL AND p_address_id > 0 THEN
        -- Actualizar dirección existente
        UPDATE professional_addresses SET
            name = p_name,
            address_line = p_address_line,
            reference = p_reference,
            district = p_district,
            province = p_province,
            department = p_department,
            latitude = p_latitude,
            longitude = p_longitude,
            phone = p_phone,
            address_type = p_address_type,
            custom_price = p_custom_price,
            is_primary = p_is_primary,
            is_active = p_is_active,
            updated_at = NOW()
        WHERE id = p_address_id AND professional_profile_id = v_professional_id
        RETURNING id INTO v_address_id;
    ELSE
        -- Crear nueva dirección
        INSERT INTO professional_addresses (
            professional_profile_id, name, address_line, reference,
            district, province, department, latitude, longitude,
            phone, address_type, custom_price, is_primary, is_active
        ) VALUES (
            v_professional_id, p_name, p_address_line, p_reference,
            p_district, p_province, p_department, p_latitude, p_longitude,
            p_phone, p_address_type, p_custom_price, p_is_primary, p_is_active
        ) RETURNING id INTO v_address_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'address_id', v_address_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Eliminar dirección del profesional
CREATE OR REPLACE FUNCTION delete_professional_address(
    p_profile_id BIGINT,
    p_address_id BIGINT
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

    -- No permitir eliminar si es la única dirección activa
    IF (
        SELECT COUNT(*) FROM professional_addresses
        WHERE professional_profile_id = v_professional_id AND is_active = true
    ) <= 1 AND EXISTS (
        SELECT 1 FROM professional_addresses
        WHERE id = p_address_id AND is_active = true
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'No se puede eliminar la única dirección activa');
    END IF;

    -- Desactivar en lugar de eliminar (soft delete)
    UPDATE professional_addresses
    SET is_active = false, updated_at = NOW()
    WHERE id = p_address_id AND professional_profile_id = v_professional_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 2. DISPONIBILIDAD POR DIRECCIÓN Y FECHA (professional_address_availability)
-- ============================================================================

-- RPC: Obtener disponibilidad de una dirección por rango de fechas
CREATE OR REPLACE FUNCTION get_address_availability(
    p_address_id BIGINT,
    p_date_from DATE DEFAULT CURRENT_DATE,
    p_date_to DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days')
) RETURNS JSONB AS $$
DECLARE
    v_availability JSONB;
BEGIN
    -- Verificar que la dirección existe y está activa
    IF NOT EXISTS (
        SELECT 1 FROM professional_addresses
        WHERE id = p_address_id AND is_active = true
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dirección no encontrada o inactiva');
    END IF;

    SELECT jsonb_agg(jsonb_build_object(
        'id', paa.id,
        'availability_date', paa.availability_date,
        'start_time', paa.start_time,
        'end_time', paa.end_time,
        'available_slots', paa.available_slots,
        'is_active', paa.is_active,
        'notes', paa.notes
    ) ORDER BY paa.availability_date) INTO v_availability
    FROM professional_address_availability paa
    WHERE paa.professional_address_id = p_address_id
        AND paa.is_active = true
        AND paa.availability_date >= p_date_from
        AND paa.availability_date <= p_date_to;

    RETURN jsonb_build_object(
        'success', true,
        'availability', COALESCE(v_availability, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- RPC: Obtener slots disponibles para una fecha específica
CREATE OR REPLACE FUNCTION get_address_day_slots(
    p_address_id BIGINT,
    p_date DATE
) RETURNS JSONB AS $$
DECLARE
    v_day_slots JSONB;
    v_day_record RECORD;
BEGIN
    -- Buscar disponibilidad para ese día
    SELECT * INTO v_day_record
    FROM professional_address_availability
    WHERE professional_address_id = p_address_id
        AND availability_date = p_date
        AND is_active = true;

    IF v_day_record IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'date', p_date,
            'has_availability', false,
            'slots', '[]'::jsonb,
            'message', 'No hay disponibilidad para este día'
        );
    END IF;

    -- Obtener slots disponibles (ya almacenados en available_slots)
    -- En el modelo v2 los slots ya vienen como array de TIME
    RETURN jsonb_build_object(
        'success', true,
        'date', p_date,
        'has_availability', true,
        'start_time', v_day_record.start_time,
        'end_time', v_day_record.end_time,
        'available_slots', v_day_record.available_slots,
        'notes', v_day_record.notes
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- RPC: Configurar disponibilidad de una dirección (upsert + deactivate)
CREATE OR REPLACE FUNCTION set_address_availability(
    p_profile_id BIGINT,
    p_address_id BIGINT,
    p_availability JSONB
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_day JSONB;
    v_day_id BIGINT;
    v_day_ids BIGINT[] := '{}'::BIGINT[];
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Verificar que la dirección pertenece al profesional
    IF NOT EXISTS (
        SELECT 1 FROM professional_addresses
        WHERE id = p_address_id AND professional_profile_id = v_professional_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dirección no pertenece a este profesional');
    END IF;

    -- Procesar cada día de disponibilidad
    FOR v_day IN SELECT * FROM jsonb_array_elements(p_availability)
    LOOP
        v_day_id := NULLIF(v_day->>'id', '')::BIGINT;

        IF v_day_id IS NOT NULL THEN
            -- Actualizar día existente
            UPDATE professional_address_availability SET
                start_time = (v_day->>'start_time')::TIME,
                end_time = (v_day->>'end_time')::TIME,
                available_slots = COALESCE(
                    (
                        SELECT array_agg(slot_value::TIME)
                        FROM jsonb_array_elements_text(
                            COALESCE(v_day->'available_slots', '[]'::jsonb)
                        ) AS slot_value
                    ),
                    '{}'::TIME[]
                ),
                is_active = COALESCE((v_day->>'is_active')::BOOLEAN, true),
                notes = v_day->>'notes',
                updated_at = NOW()
            WHERE id = v_day_id AND professional_address_id = p_address_id
            RETURNING id INTO v_day_id;
            v_day_ids := array_append(v_day_ids, v_day_id);
        ELSE
            -- Insertar nuevo día
            INSERT INTO professional_address_availability (
                professional_address_id,
                availability_date,
                start_time,
                end_time,
                available_slots,
                is_active,
                notes
            ) VALUES (
                p_address_id,
                (v_day->>'date')::DATE,
                (v_day->>'start_time')::TIME,
                (v_day->>'end_time')::TIME,
                COALESCE(
                    (
                        SELECT array_agg(slot_value::TIME)
                        FROM jsonb_array_elements_text(
                            COALESCE(v_day->'available_slots', '[]'::jsonb)
                        ) AS slot_value
                    ),
                    '{}'::TIME[]
                ),
                COALESCE((v_day->>'is_active')::BOOLEAN, true),
                v_day->>'notes'
            ) RETURNING id INTO v_day_id;
            v_day_ids := array_append(v_day_ids, v_day_id);
        END IF;
    END LOOP;

    -- Desactivar días que no vinieron en el payload
    UPDATE professional_address_availability
    SET is_active = false, updated_at = NOW()
    WHERE professional_address_id = p_address_id
      AND (array_length(v_day_ids, 1) IS NULL OR id <> ALL (v_day_ids));

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Deshabilitar un slot específico
CREATE OR REPLACE FUNCTION disable_availability_slot(
    p_profile_id BIGINT,
    p_address_id BIGINT,
    p_date DATE,
    p_time TIME
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_record RECORD;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Verificar que la dirección pertenece al profesional
    IF NOT EXISTS (
        SELECT 1 FROM professional_addresses
        WHERE id = p_address_id AND professional_profile_id = v_professional_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dirección no pertenece a este profesional');
    END IF;

    -- Buscar el día de disponibilidad
    SELECT * INTO v_record
    FROM professional_address_availability
    WHERE professional_address_id = p_address_id AND availability_date = p_date AND is_active = true;

    IF v_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No existe disponibilidad para este día');
    END IF;

    -- Remover el slot del array (si existe)
    UPDATE professional_address_availability
    SET available_slots = array_remove(available_slots, p_time),
        updated_at = NOW()
    WHERE id = v_record.id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 3. SOLICITUDES DE CITA (professional_appointment_requests)
-- ============================================================================

-- RPC: Cliente crea solicitud de cita (NO bloquea slot)
CREATE OR REPLACE FUNCTION create_appointment_request(
    p_professional_id BIGINT,
    p_client_profile_id BIGINT,
    p_address_id BIGINT,
    p_service_id BIGINT DEFAULT NULL,
    p_requested_date DATE DEFAULT NULL,
    p_requested_time TIME DEFAULT NULL,
    p_pet_name TEXT DEFAULT NULL,
    p_pet_description TEXT DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_request_id BIGINT;
BEGIN
    -- Validar que el profesional existe y está publicado
    IF NOT EXISTS (
        SELECT 1 FROM professional_profiles
        WHERE id = p_professional_id AND status = 'approved' AND is_published = true AND is_available = true
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Profesional no disponible');
    END IF;

    -- Validar que el profesional no se agende a sí mismo
    IF p_professional_id = p_client_profile_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'No puedes agendar una cita contigo mismo');
    END IF;

    -- Validar que la dirección existe y está activa
    IF NOT EXISTS (
        SELECT 1 FROM professional_addresses
        WHERE id = p_address_id AND professional_profile_id = p_professional_id AND is_active = true
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dirección no válida');
    END IF;

    -- Validar cliente
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_client_profile_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cliente no encontrado');
    END IF;

    -- Validar motivo requerido
    IF p_reason IS NULL OR p_reason = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Motivo de consulta es requerido');
    END IF;

    -- Insertar solicitud (el slot NO se bloquea - solo se registra la solicitud)
    INSERT INTO professional_appointment_requests (
        professional_profile_id,
        client_profile_id,
        professional_address_id,
        service_id,
        requested_date,
        requested_time,
        pet_name,
        pet_description,
        reason,
        status
    ) VALUES (
        p_professional_id,
        p_client_profile_id,
        p_address_id,
        p_service_id,
        p_requested_date,
        p_requested_time,
        p_pet_name,
        p_pet_description,
        p_reason,
        'pending'
    ) RETURNING id INTO v_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_request_id,
        'message', 'Solicitud enviada. El profesional responderá pronto.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Profesional acepta solicitud
CREATE OR REPLACE FUNCTION accept_appointment_request(
    p_request_id BIGINT,
    p_professional_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_request RECORD;
BEGIN
    -- Obtener solicitud
    SELECT * INTO v_request
    FROM professional_appointment_requests
    WHERE id = p_request_id AND professional_profile_id = p_professional_id;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;

    IF v_request.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud ya no está pendiente');
    END IF;

    -- Actualizar estado
    UPDATE professional_appointment_requests
    SET status = 'accepted',
        responded_at = NOW(),
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'message', 'Solicitud aceptada');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Profesional rechaza solicitud (con motivo obligatorio)
CREATE OR REPLACE FUNCTION reject_appointment_request(
    p_request_id BIGINT,
    p_professional_id BIGINT,
    p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
    v_request RECORD;
BEGIN
    -- Validar motivo
    IF p_reason IS NULL OR p_reason = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Motivo de rechazo es requerido');
    END IF;

    -- Obtener solicitud
    SELECT * INTO v_request
    FROM professional_appointment_requests
    WHERE id = p_request_id AND professional_profile_id = p_professional_id;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;

    IF v_request.status NOT IN ('pending', 'accepted') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no puede ser rechazada en su estado actual');
    END IF;

    -- Actualizar estado
    UPDATE professional_appointment_requests
    SET status = 'rejected',
        rejection_reason = p_reason,
        responded_at = NOW(),
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'message', 'Solicitud rechazada');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Profesional marca solicitud como completada (habilita review)
CREATE OR REPLACE FUNCTION complete_appointment_request(
    p_request_id BIGINT,
    p_professional_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_request RECORD;
    v_client_user_id UUID;
BEGIN
    -- Obtener solicitud
    SELECT * INTO v_request
    FROM professional_appointment_requests
    WHERE id = p_request_id AND professional_profile_id = p_professional_id;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;

    IF v_request.status != 'accepted' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden completar solicitudes aceptadas');
    END IF;

    -- Actualizar estado
    UPDATE professional_appointment_requests
    SET status = 'completed',
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_request_id;

    -- Insertar notificación para el cliente
    SELECT user_id INTO v_client_user_id
    FROM profiles
    WHERE id = v_request.client_profile_id;

    IF v_client_user_id IS NOT NULL THEN
        INSERT INTO notifications (
            user_id,
            type,
            title,
            message,
            reference_type,
            reference_id
        ) VALUES (
            v_client_user_id,
            'appointment_completed',
            'Cita completada',
            'Tu cita para ' || COALESCE(v_request.pet_name, 'tu mascota') || ' ha finalizado. ¡Déjanos tu reseña!',
            'professional_appointment_requests',
            p_request_id::TEXT
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Atención completada. El cliente puede dejar un review.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Cliente cancela su solicitud
CREATE OR REPLACE FUNCTION cancel_appointment_request(
    p_request_id BIGINT,
    p_client_profile_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_request RECORD;
BEGIN
    -- Obtener solicitud
    SELECT * INTO v_request
    FROM professional_appointment_requests
    WHERE id = p_request_id AND client_profile_id = p_client_profile_id;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;

    IF v_request.status NOT IN ('pending', 'accepted') THEN
        RETURN jsonb_build_object('success', false, 'error', 'No se puede cancelar en el estado actual');
    END IF;

    -- Actualizar estado
    UPDATE professional_appointment_requests
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'message', 'Solicitud cancelada');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Profesional marca como no-show
CREATE OR REPLACE FUNCTION mark_no_show_appointment_request(
    p_request_id BIGINT,
    p_professional_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_request RECORD;
BEGIN
    SELECT * INTO v_request
    FROM professional_appointment_requests
    WHERE id = p_request_id AND professional_profile_id = p_professional_id;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;

    IF v_request.status != 'accepted' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden marcar no-show solicitudes aceptadas');
    END IF;

    UPDATE professional_appointment_requests
    SET status = 'no_show',
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. PREGUNTAS FRECUENTES (professional_faqs)
-- ============================================================================

-- RPC: Obtener FAQs del profesional (privado - para el owner)
CREATE OR REPLACE FUNCTION get_professional_faqs(
    p_profile_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_faqs JSONB;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    SELECT jsonb_agg(jsonb_build_object(
        'id', pf.id,
        'question', pf.question,
        'answer', pf.answer,
        'display_order', pf.display_order,
        'is_active', pf.is_active,
        'created_at', pf.created_at,
        'updated_at', pf.updated_at
    ) ORDER BY pf.display_order, pf.id) INTO v_faqs
    FROM professional_faqs pf
    WHERE pf.professional_profile_id = v_professional_id;

    RETURN jsonb_build_object(
        'success', true,
        'faqs', COALESCE(v_faqs, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear o actualizar FAQ del profesional
CREATE OR REPLACE FUNCTION upsert_professional_faq(
    p_profile_id BIGINT,
    p_faq_id BIGINT DEFAULT NULL,
    p_question TEXT DEFAULT NULL,
    p_answer TEXT DEFAULT NULL,
    p_display_order INTEGER DEFAULT 0,
    p_is_active BOOLEAN DEFAULT true
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_faq_id BIGINT;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Validar campos requeridos
    IF p_question IS NULL OR p_question = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'La pregunta es requerida');
    END IF;
    IF p_answer IS NULL OR p_answer = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'La respuesta es requerida');
    END IF;

    IF p_faq_id IS NOT NULL AND p_faq_id > 0 THEN
        -- Actualizar FAQ existente
        UPDATE professional_faqs SET
            question = p_question,
            answer = p_answer,
            display_order = p_display_order,
            is_active = p_is_active,
            updated_at = NOW()
        WHERE id = p_faq_id AND professional_profile_id = v_professional_id
        RETURNING id INTO v_faq_id;
    ELSE
        -- Crear nueva FAQ
        INSERT INTO professional_faqs (
            professional_profile_id, question, answer, display_order, is_active
        ) VALUES (
            v_professional_id, p_question, p_answer, p_display_order, p_is_active
        ) RETURNING id INTO v_faq_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'faq_id', v_faq_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Eliminar FAQ del profesional
CREATE OR REPLACE FUNCTION delete_professional_faq(
    p_profile_id BIGINT,
    p_faq_id BIGINT
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

    DELETE FROM professional_faqs
    WHERE id = p_faq_id AND professional_profile_id = v_professional_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 4. REVIEWS (professional_reviews) - Vinculados a appointment_requests
-- ============================================================================

-- RPC: Cliente crea review (solo si appointment request está completed)
CREATE OR REPLACE FUNCTION create_professional_review(
    p_request_id BIGINT,
    p_client_profile_id BIGINT,
    p_rating INTEGER,
    p_comment TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_request RECORD;
    v_review_id BIGINT;
BEGIN
    -- Obtener solicitud
    SELECT * INTO v_request
    FROM professional_appointment_requests
    WHERE id = p_request_id AND client_profile_id = p_client_profile_id;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;

    -- Validar que está completada
    IF v_request.status != 'completed' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Solo puedes dejar un review después de que el profesional marque la atención como completada'
        );
    END IF;

    -- Validar rating (1-5)
    IF p_rating < 1 OR p_rating > 5 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Rating debe ser entre 1 y 5');
    END IF;

    -- Verificar que no existe ya un review para esta solicitud
    IF EXISTS (
        SELECT 1 FROM professional_reviews
        WHERE appointment_request_id = p_request_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Ya existe un review para esta solicitud');
    END IF;

    -- Crear review
    INSERT INTO professional_reviews (
        professional_profile_id,
        client_profile_id,
        appointment_request_id,
        rating,
        comment
    ) VALUES (
        v_request.professional_profile_id,
        p_client_profile_id,
        p_request_id,
        p_rating,
        p_comment
    ) RETURNING id INTO v_review_id;

    RETURN jsonb_build_object(
        'success', true,
        'review_id', v_review_id,
        'message', 'Gracias por tu review!'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Profesional responde a un review
CREATE OR REPLACE FUNCTION respond_professional_review(
    p_review_id BIGINT,
    p_professional_id BIGINT,
    p_response TEXT
) RETURNS JSONB AS $$
DECLARE
    v_review RECORD;
BEGIN
    -- Validar respuesta
    IF p_response IS NULL OR p_response = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Respuesta es requerida');
    END IF;

    -- Obtener review y verificar propiedad
    SELECT * INTO v_review
    FROM professional_reviews
    WHERE id = p_review_id AND professional_profile_id = p_professional_id;

    IF v_review IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Review no encontrado');
    END IF;

    -- Actualizar respuesta
    UPDATE professional_reviews
    SET professional_response = p_response,
        responded_at = NOW()
    WHERE id = p_review_id;

    RETURN jsonb_build_object('success', true, 'message', 'Respuesta publicada');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 5. OBTENER DATOS PÚBLICOS (para fichas de profesionales)
-- ============================================================================

-- RPC: Obtener detalle público de profesional (incluye modelo v2)
DROP FUNCTION IF EXISTS get_professional_public_detail_v2(TEXT);
CREATE OR REPLACE FUNCTION get_professional_public_detail_v2(
    p_professional_id TEXT
) RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
    v_services JSONB;
    v_addresses JSONB;
    v_reviews JSONB;
    v_faqs JSONB;
    v_availability JSONB;
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
    WHERE ps.professional_profile_id = v_profile.id AND ps.is_active = true;

    -- Obtener direcciones activas (modelo v2)
    SELECT jsonb_agg(jsonb_build_object(
        'id', pa.id,
        'name', pa.name,
        'address_line', pa.address_line,
        'district', pa.district,
        'province', pa.province,
        'latitude', pa.latitude,
        'longitude', pa.longitude,
        'phone', pa.phone,
        'is_primary', pa.is_primary
    ) ORDER BY pa.is_primary DESC, pa.id) INTO v_addresses
    FROM professional_addresses pa
    WHERE pa.professional_profile_id = v_profile.id AND pa.is_active = true;

    -- Obtener reseñas
    SELECT jsonb_agg(jsonb_build_object(
        'id', pr.id,
        'reviewer_name', COALESCE(p.full_name, 'Cliente verificado'),
        'rating', pr.rating,
        'comment', pr.comment,
        'professional_response', pr.professional_response,
        'responded_at', pr.responded_at,
        'created_at', pr.created_at
    ) ORDER BY pr.created_at DESC) INTO v_reviews
    FROM professional_reviews pr
    LEFT JOIN profiles p ON p.id = pr.client_profile_id
    WHERE pr.professional_profile_id = v_profile.id
    LIMIT 10;

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
        'faqs', COALESCE(v_faqs, '[]'::jsonb),
        'availability', COALESCE(v_availability, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;


-- ============================================================================
-- 6. PANEL DEL PROFESIONAL - SOLICITUDES RECIBIDAS
-- ============================================================================

-- RPC: Obtener solicitudes de cita recibidas por el profesional
CREATE OR REPLACE FUNCTION get_professional_appointment_requests(
    p_profile_id BIGINT,
    p_status TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_professional_id BIGINT;
    v_requests JSONB;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT id INTO v_professional_id FROM professional_profiles WHERE profile_id = p_profile_id;
    IF v_professional_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Perfil no encontrado');
    END IF;

    -- Obtener solicitudes
    SELECT jsonb_agg(jsonb_build_object(
        'id', par.id,
        'requested_date', par.requested_date,
        'requested_time', par.requested_time,
        'pet_name', par.pet_name,
        'pet_description', par.pet_description,
        'reason', par.reason,
        'status', par.status::text,
        'rejection_reason', par.rejection_reason,
        'responded_at', par.responded_at,
        'completed_at', par.completed_at,
        'client_name', p.full_name,
        'client_email', p.user_id,
        'address_id', par.professional_address_id,
        'address_name', pa.name,
        'service_id', par.service_id,
        'service_name', ps.name,
        'created_at', par.created_at
    ) ORDER BY par.created_at DESC) INTO v_requests
    FROM professional_appointment_requests par
    LEFT JOIN profiles p ON p.id = par.client_profile_id
    LEFT JOIN professional_addresses pa ON pa.id = par.professional_address_id
    LEFT JOIN professional_services ps ON ps.id = par.service_id
    WHERE par.professional_profile_id = v_professional_id
        AND (p_status IS NULL OR par.status::text = p_status);

    RETURN jsonb_build_object(
        'success', true,
        'requests', COALESCE(v_requests, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Obtener solicitudes de cita del cliente (mis solicitudes)
CREATE OR REPLACE FUNCTION get_my_appointment_requests(
    p_client_profile_id BIGINT,
    p_status TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_requests JSONB;
BEGIN
    -- Validar identidad
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_client_profile_id AND user_id = auth.uid()) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT jsonb_agg(jsonb_build_object(
        'id', par.id,
        'professional_name', pp.public_name,
        'professional_title', pp.title,
        'address_name', pa.name,
        'address_district', pa.district,
        'requested_date', par.requested_date,
        'requested_time', par.requested_time,
        'pet_name', par.pet_name,
        'reason', par.reason,
        'status', par.status::text,
        'rejection_reason', par.rejection_reason,
        'professional_response', pr_response.professional_response,
        'has_review', EXISTS(SELECT 1 FROM professional_reviews WHERE appointment_request_id = par.id),
        'created_at', par.created_at
    ) ORDER BY par.created_at DESC) INTO v_requests
    FROM professional_appointment_requests par
    JOIN professional_profiles pp ON pp.id = par.professional_profile_id
    LEFT JOIN professional_addresses pa ON pa.id = par.professional_address_id
    LEFT JOIN professional_reviews pr_response ON pr_response.appointment_request_id = par.id
    WHERE par.client_profile_id = p_client_profile_id
        AND (p_status IS NULL OR par.status::text = p_status);

    RETURN jsonb_build_object(
        'success', true,
        'requests', COALESCE(v_requests, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;