-- ============================================================
-- PARTE 1 CORREGIDA
-- ACTUALIZACIÓN DEL MÓDULO PROFESSIONALS SEGÚN PRODUCT BACKLOG
-- Modelo Doctoralia-style v2:
-- - Direcciones múltiples
-- - Disponibilidad por dirección y fecha
-- - Solicitudes de cita
-- - Reviews vinculadas a solicitudes de cita
--
-- MODELO DE TABLAS:
-- - professional_addresses      → NUEVO modelo v2 (reemplaza al legacy)
-- - professional_addresses_legacy → Modelo anterior (label + address_text simples)
--
-- El frontend LEGACY usa professional_addresses_legacy.
-- El frontend NUEVO (modelo Doctoralia) usa professional_addresses.
--
-- DEPENDENCIAS:
-- - Requiere que exista el enum appointment_request_status (creado en este archivo)
-- - Requiere que professional_profiles tenga las columnas: slug, is_available, phone
--   (añadidas por 08_professional_directory_seo_patch.sql)
-- ============================================================


-- ============================================================
-- 0. MARCAR TABLAS ANTIGUAS COMO LEGACY
-- No se borran. Solo se documenta que serán reemplazadas.
-- ============================================================

COMMENT ON TABLE public.professional_availability IS
'LEGACY: tabla actual usada por el frontend. Será reemplazada progresivamente por professional_address_availability. No borrar mientras el frontend dependa de ella.';

COMMENT ON TABLE public.professional_appointments IS
'LEGACY: tabla actual usada por el frontend. Será reemplazada progresivamente por professional_appointment_requests. No borrar mientras el frontend dependa de ella.';


-- ============================================================
-- 1. ASEGURAR QUE professional_profiles TENGA LOS CAMPOS NUEVOS
-- Estos campos ya existen via 08_professional_directory_seo_patch.sql
-- Se usa ADD COLUMN IF NOT EXISTS para ser idempotente.
-- ============================================================

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS slug text UNIQUE;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS phone text;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS treated_conditions text;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS average_rating numeric DEFAULT 0.00;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS total_reviews integer DEFAULT 0;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS profile_photo_url text;

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS gallery_urls text[] DEFAULT '{}';

ALTER TABLE public.professional_profiles
ADD COLUMN IF NOT EXISTS consultation_types text[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_professional_profiles_slug
ON public.professional_profiles(slug)
WHERE slug IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_professional_profiles_public
ON public.professional_profiles(status, is_published, is_available);

CREATE INDEX IF NOT EXISTS idx_professional_profiles_rating
ON public.professional_profiles(average_rating DESC, total_reviews DESC);


-- ============================================================
-- 2. NUEVO ENUM: appointment_request_status
-- Estados de solicitud de cita (modelo Doctoralia-style)
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'appointment_request_status'
        AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.appointment_request_status AS ENUM (
            'pending',
            'accepted',
            'rejected',
            'cancelled',
            'completed',
            'no_show'
        );
    END IF;
END $$;


-- ============================================================
-- 3. TABLA NUEVA: professional_addresses (Modelo v2)
-- Direcciones / sedes / consultorios del profesional.
--
-- NOTA: Esta tabla es NUEVA y diferente del modelo legacy.
-- Esta tabla usa el modelo completo con district/province/department.
-- La tabla legacy "professional_addresses_legacy" ya existe como referencia.
-- ============================================================

-- Tabla principal del modelo v2 (reemplaza a professional_addresses_legacy).
-- Esta tabla representa el MODELO v2 con campos estructurados:
-- name, address_line, reference, district, province, department.
-- El frontend LEGACY usa professional_addresses_legacy.
-- El frontend NUEVO (modelo Doctoralia) usa esta tabla.
CREATE TABLE IF NOT EXISTS public.professional_addresses (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    professional_profile_id bigint NOT NULL,

    -- Nombre de la sede (ej: "Consultorio principal", "Sede Miraflores")
    name text NOT NULL DEFAULT 'Consultorio principal',

    -- Dirección estructurada
    address_line text NOT NULL,
    reference text,
    district text NOT NULL,
    province text NOT NULL DEFAULT 'Lima',
    department text NOT NULL DEFAULT 'Lima',

    -- Coordenadas GPS
    latitude numeric,
    longitude numeric,

    -- Teléfono de contacto de la sede
    phone text,

    -- Tipo de sede (physical, virtual, home_visit)
    address_type text NOT NULL DEFAULT 'physical',
    
    -- Precio personalizado para esta sede (si es nulo, usa el base_price del perfil)
    custom_price numeric,

    -- Indicadores
    is_primary boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,

    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT professional_addresses_pkey PRIMARY KEY (id),

    CONSTRAINT professional_addresses_professional_profile_id_fkey
        FOREIGN KEY (professional_profile_id)
        REFERENCES public.professional_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT professional_addresses_type_check
        CHECK (address_type IN ('physical', 'virtual', 'home_visit'))
);

CREATE INDEX IF NOT EXISTS idx_professional_addresses_professional
ON public.professional_addresses(professional_profile_id);

CREATE INDEX IF NOT EXISTS idx_professional_addresses_location
ON public.professional_addresses(district, province, department)
WHERE is_active = true;

-- Solo una dirección primary por profesional
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_primary_address_per_professional
ON public.professional_addresses(professional_profile_id)
WHERE is_primary = true;


-- ============================================================
-- 4. TABLA NUEVA: professional_address_availability (Modelo v2)
-- Disponibilidad por dirección y fecha específica.
-- El frontend NUEVO usará esta tabla.
-- La tabla legacy professional_availability (day_of_week) se mantiene para el frontend actual.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professional_address_availability (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    professional_address_id bigint NOT NULL,

    availability_date date NOT NULL,

    -- Ventana horaria
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,

    -- Slots disponibles específicos (ej: ['09:00', '09:30', '10:00'])
    -- El profesional define los slots exactos disponibles para ese día
    available_slots time without time zone[] NOT NULL DEFAULT '{}',

    is_active boolean NOT NULL DEFAULT true,
    notes text,

    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT professional_address_availability_pkey PRIMARY KEY (id),

    CONSTRAINT professional_address_availability_address_fkey
        FOREIGN KEY (professional_address_id)
        REFERENCES public.professional_addresses(id)
        ON DELETE CASCADE,

    CONSTRAINT professional_address_availability_time_check
        CHECK (end_time > start_time),

    CONSTRAINT professional_address_availability_unq
        UNIQUE (professional_address_id, availability_date)
);

CREATE INDEX IF NOT EXISTS idx_address_availability_date
ON public.professional_address_availability(availability_date)
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_address_availability_address_date
ON public.professional_address_availability(professional_address_id, availability_date)
WHERE is_active = true;


-- ============================================================
-- 5. TABLA NUEVA: professional_appointment_requests
-- Solicitudes de cita (modelo Doctoralia-style).
--
-- El cliente SOLICITA, el profesional ACEPTA/RECHAZA.
-- El slot NO se bloquea al enviar la solicitud - queda disponible
-- hasta que el profesional lo deshabilite manualmente.
-- Solo cuando el profesional marca "completado" se habilita el review.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professional_appointment_requests (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,

    professional_profile_id bigint NOT NULL,
    client_profile_id bigint NOT NULL,
    professional_address_id bigint NOT NULL,
    service_id bigint,

    -- Fecha y hora SOLICITADA (no reservada)
    requested_date date NOT NULL,
    requested_time time without time zone NOT NULL,

    -- Datos de la mascota
    pet_name text,
    pet_description text,

    -- Motivo de la consulta
    reason text NOT NULL,

    -- Estado de la solicitud
    status public.appointment_request_status NOT NULL DEFAULT 'pending',

    -- Respuesta del profesional
    rejection_reason text,
    responded_at timestamp with time zone,

    -- Nota interna del profesional
    internal_notes text,

    -- Cuando se marca como completado (habilita review)
    completed_at timestamp with time zone,

    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT professional_appointment_requests_pkey PRIMARY KEY (id),

    CONSTRAINT appointment_requests_professional_profile_id_fkey
        FOREIGN KEY (professional_profile_id)
        REFERENCES public.professional_profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT appointment_requests_client_profile_id_fkey
        FOREIGN KEY (client_profile_id)
        REFERENCES public.profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT appointment_requests_professional_address_id_fkey
        FOREIGN KEY (professional_address_id)
        REFERENCES public.professional_addresses(id)
        ON DELETE CASCADE,

    CONSTRAINT appointment_requests_service_id_fkey
        FOREIGN KEY (service_id)
        REFERENCES public.professional_services(id)
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_professional_client
ON public.professional_appointment_requests(professional_profile_id, client_profile_id);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_status
ON public.professional_appointment_requests(status);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_date
ON public.professional_appointment_requests(requested_date);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_address_date
ON public.professional_appointment_requests(professional_address_id, requested_date);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_professional_status
ON public.professional_appointment_requests(professional_profile_id, status);


-- ============================================================
-- 6. AJUSTE A professional_reviews
-- Se vinculan reseñas al nuevo flujo de solicitudes de cita.
-- La reseña solo puede crearse cuando appointment_request_id está
-- completado (status = 'completed').
-- ============================================================

ALTER TABLE public.professional_reviews
ADD COLUMN IF NOT EXISTS appointment_request_id bigint;

ALTER TABLE public.professional_reviews
ADD COLUMN IF NOT EXISTS professional_response text;

ALTER TABLE public.professional_reviews
ADD COLUMN IF NOT EXISTS responded_at timestamp with time zone;

-- FK solo si la constraint no existe (idempotente)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
        AND table_name = 'professional_reviews'
        AND constraint_name = 'professional_reviews_appointment_request_id_fkey'
    ) THEN
        ALTER TABLE public.professional_reviews
        ADD CONSTRAINT professional_reviews_appointment_request_id_fkey
        FOREIGN KEY (appointment_request_id)
        REFERENCES public.professional_appointment_requests(id)
        ON DELETE CASCADE;
    END IF;
END $$;

-- Solo 1 review por solicitud de cita
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_review_per_appointment_request
ON public.professional_reviews(appointment_request_id)
WHERE appointment_request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_professional_reviews_professional
ON public.professional_reviews(professional_profile_id);

CREATE INDEX IF NOT EXISTS idx_professional_reviews_client
ON public.professional_reviews(client_profile_id);


-- ============================================================
-- 7. TRIGGER PARA ACTUALIZAR RATING DEL PROFESIONAL
-- Actualiza: professional_profiles.average_rating y total_reviews
-- Cada vez que se inserta/actualiza/borra una review.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_professional_rating_stats()
RETURNS trigger AS $$
DECLARE
    v_professional_id bigint;
BEGIN
    v_professional_id := COALESCE(NEW.professional_profile_id, OLD.professional_profile_id);

    UPDATE public.professional_profiles
    SET
        average_rating = COALESCE((
            SELECT ROUND(AVG(rating)::numeric, 2)
            FROM public.professional_reviews
            WHERE professional_profile_id = v_professional_id
        ), 0),
        total_reviews = COALESCE((
            SELECT COUNT(*)
            FROM public.professional_reviews
            WHERE professional_profile_id = v_professional_id
        ), 0),
        updated_at = now()
    WHERE id = v_professional_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_professional_rating ON public.professional_reviews;

CREATE TRIGGER trg_update_professional_rating
AFTER INSERT OR UPDATE OR DELETE ON public.professional_reviews
FOR EACH ROW
EXECUTE FUNCTION public.update_professional_rating_stats();


-- ============================================================
-- 8. MIGRACIÓN OPCIONAL: Crear dirección principal para profesionales
-- existentes que tienen address_text, latitude y longitude.
--
-- Esto migra los profesionales LEGACY al nuevo modelo v2 creando
-- una entrada en professional_addresses desde los campos antiguos.
-- ============================================================

INSERT INTO public.professional_addresses (
    professional_profile_id,
    name,
    address_line,
    district,
    province,
    department,
    latitude,
    longitude,
    phone,
    is_primary,
    is_active
)
SELECT
    pp.id,
    'Consultorio principal',
    COALESCE(pp.address_text, 'Dirección no especificada'),
    'Lima',
    'Lima',
    'Lima',
    pp.latitude,
    pp.longitude,
    pp.phone,
    true,
    true
FROM public.professional_profiles pp
WHERE pp.address_text IS NOT NULL
AND NOT EXISTS (
    SELECT 1
    FROM public.professional_addresses pa
    WHERE pa.professional_profile_id = pp.id
);