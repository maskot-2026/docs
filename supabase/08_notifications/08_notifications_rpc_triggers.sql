-- ============================================================================
-- Componente: Notifications
-- Módulo: 08_notifications_rpc_triggers
-- Descripción: Triggers para insertar notificaciones automáticamente
-- ============================================================================

-- Función Trigger para Citas
CREATE OR REPLACE FUNCTION public.tr_create_appointment_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_professional_user_id UUID;
    v_pet_name TEXT;
    v_client_name TEXT;
BEGIN
    -- 1. Obtener el user_id del profesional a partir del professional_profile_id
    SELECT pr.user_id INTO v_professional_user_id
    FROM public.professional_profiles pp
    JOIN public.profiles pr ON pr.id = pp.profile_id
    WHERE pp.id = NEW.professional_profile_id;

    -- 2. Obtener datos del cliente y mascota (si existen)
    -- NEW.client_profile_id, NEW.pet_name
    SELECT full_name INTO v_client_name
    FROM public.profiles
    WHERE id = NEW.client_profile_id;

    v_pet_name := COALESCE(NEW.pet_name, 'su mascota');

    -- 3. Insertar notificación para el profesional
    IF v_professional_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
            user_id,
            type,
            title,
            message,
            reference_type,
            reference_id
        ) VALUES (
            v_professional_user_id,
            'new_appointment_request',
            'Nueva solicitud de cita',
            'El cliente ' || COALESCE(v_client_name, 'Desconocido') || ' ha solicitado una cita para ' || v_pet_name || '.',
            'professional_appointment_requests',
            NEW.id::text
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear el Trigger en la tabla de citas
DROP TRIGGER IF EXISTS trg_appointment_notification ON public.professional_appointment_requests;

CREATE TRIGGER trg_appointment_notification
AFTER INSERT ON public.professional_appointment_requests
FOR EACH ROW
EXECUTE FUNCTION public.tr_create_appointment_notification();
