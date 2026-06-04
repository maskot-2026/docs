-- ============================================================
-- PARTE 2 CORREGIDA
-- TABLAS EXTRA ESTILO DOCTORALIA
--
-- Estas tablas complementan el perfil público del profesional.
--
-- SEGÚN LO CONVERSADO:
-- - NO se agrega professional_languages
-- - NO se agrega professional_address_payment_methods
--
-- SE AGREGAN:
-- - professional_experience_items (educación, experiencia, certificaciones)
-- - professional_address_services (servicios por dirección)
-- - professional_faqs (preguntas frecuentes del profesional)
--
-- NOTA: Estas tablas son OPTIONAL para el MVP.
-- El perfil público funciona sin ellas.
-- Se incluyen para hacer más completo el Directorio.
-- ============================================================


-- ============================================================
-- 1. TABLA EXTRA: professional_experience_items
-- Experiencia, formación, certificaciones y premios.
--
-- Complementa a professional_profiles.experience_summary.
-- - experience_summary: resumen breve tipo presentación
-- - professional_experience_items: lista estructurada de formación,
--   experiencia y certificaciones
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professional_experience_items (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    professional_profile_id bigint NOT NULL,

    -- Tipo de item: education, experience, certification, award
    type text NOT NULL CHECK (
        type IN ('education', 'experience', 'certification', 'award')
    ),

    title text NOT NULL,
    institution text,
    description text,

    -- Años de vigencia (null = presente)
    start_year integer,
    end_year integer,

    -- Orden de visualización
    display_order integer NOT NULL DEFAULT 0 CHECK (display_order >= 0),

    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT professional_experience_items_pkey PRIMARY KEY (id),

    CONSTRAINT professional_experience_items_professional_profile_id_fkey
        FOREIGN KEY (professional_profile_id)
        REFERENCES public.professional_profiles(id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_professional_experience_profile
ON public.professional_experience_items(professional_profile_id, display_order);


-- ============================================================
-- 2. TABLA EXTRA: professional_address_services
-- Servicios disponibles por cada dirección.
--
-- WHY: professional_services indica qué servicios ofrece el profesional.
-- Pero si el profesional tiene varias sedes, puede que no todos
-- los servicios estén disponibles en todas las sedes.
--
-- Ejemplo:
-- - Sede Miraflores: consulta general, vacunación.
-- - Sede Surco: grooming, nutrición.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professional_address_services (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,

    professional_address_id bigint NOT NULL,
    professional_service_id bigint NOT NULL,

    is_active boolean NOT NULL DEFAULT true,

    created_at timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT professional_address_services_pkey PRIMARY KEY (id),

    CONSTRAINT professional_address_services_address_fkey
        FOREIGN KEY (professional_address_id)
        REFERENCES public.professional_addresses(id)
        ON DELETE CASCADE,

    CONSTRAINT professional_address_services_service_fkey
        FOREIGN KEY (professional_service_id)
        REFERENCES public.professional_services(id)
        ON DELETE CASCADE,

    -- Una combinación única de dirección + servicio
    CONSTRAINT professional_address_services_unique
        UNIQUE (professional_address_id, professional_service_id)
);

CREATE INDEX IF NOT EXISTS idx_professional_address_services_address
ON public.professional_address_services(professional_address_id);

CREATE INDEX IF NOT EXISTS idx_professional_address_services_service
ON public.professional_address_services(professional_service_id);


-- ============================================================
-- 3. TABLA EXTRA: professional_faqs
-- Preguntas frecuentes por profesional.
--
-- Sirve para mostrar condiciones antes de solicitar cita.
--
-- Ejemplos:
-- - ¿Atiendes emergencias?
-- - ¿Debo llevar historial médico?
-- - ¿Atiendes perros y gatos?
-- - ¿El pago se realiza en tienda?
-- ============================================================

CREATE TABLE IF NOT EXISTS public.professional_faqs (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,

    professional_profile_id bigint NOT NULL,

    question text NOT NULL,
    answer text NOT NULL,

    display_order integer NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    is_active boolean NOT NULL DEFAULT true,

    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT professional_faqs_pkey PRIMARY KEY (id),

    CONSTRAINT professional_faqs_professional_profile_id_fkey
        FOREIGN KEY (professional_profile_id)
        REFERENCES public.professional_profiles(id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_professional_faqs_profile
ON public.professional_faqs(professional_profile_id, display_order)
WHERE is_active = true;


-- ============================================================
-- 4. INDEX ADICIONAL PARA professional_address_availability
-- Mejora rendimiento en consultas del calendario del profesional.
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_address_availability_professional
ON public.professional_address_availability(
    professional_address_id,
    availability_date,
    is_active
)
WHERE is_active = true;