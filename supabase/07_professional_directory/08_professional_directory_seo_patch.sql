-- ============================================================================
-- MassKot | Professional Directory SEO & Contact Patch
-- Agrega campos para URLs amigables (slug), disponibilidad (is_available),
-- y WhatsApp (phone) a professional_profiles
-- ============================================================================

-- 1. Agregar campo slug para URLs amigables (ej: /professionals/dr-juan-perez)
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE;

-- 2. Agregar campo is_available para indicar si el profesional acepta consultas
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;

-- 3. Agregar campo phone para WhatsApp
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS phone TEXT;

-- 4. Crear índice para búsqueda por slug
CREATE INDEX IF NOT EXISTS idx_professional_profiles_slug
  ON professional_profiles(slug) WHERE slug IS NOT NULL;

-- 5. Función para generar slug desde public_name
CREATE OR REPLACE FUNCTION generate_professional_slug(p_public_name TEXT)
RETURNS TEXT AS $$
DECLARE
    v_slug TEXT;
    v_counter INTEGER := 0;
BEGIN
    -- Convertir a minúsculas, reemplazar espacios y caracteres especiales
    v_slug := lower(p_public_name);
    v_slug := regexp_replace(v_slug, '[^a-z0-9\s-]', '', 'g');
    v_slug := regexp_replace(v_slug, '\s+', '-', 'g');
    v_slug := trim(both '-' from v_slug);

    -- Si está vacío después de limpiar, usar 'profesional'
    IF v_slug = '' OR v_slug IS NULL THEN
        v_slug := 'profesional';
    END IF;

    -- Verificar si ya existe y agregar sufijo si es necesario
    WHILE EXISTS (SELECT 1 FROM professional_profiles WHERE slug = v_slug) LOOP
        v_counter := v_counter + 1;
        v_slug := v_slug || '-' || v_counter;
    END LOOP;

    RETURN v_slug;
END;
$$ LANGUAGE plpgsql;

-- 6. Trigger para auto-generar slug al crear perfil
CREATE OR REPLACE FUNCTION set_professional_slug_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.slug IS NULL OR NEW.slug = '' THEN
        NEW.slug := generate_professional_slug(NEW.public_name);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_professional_slug ON professional_profiles;
CREATE TRIGGER trg_set_professional_slug
    BEFORE INSERT ON professional_profiles
    FOR EACH ROW
    EXECUTE FUNCTION set_professional_slug_on_insert();

-- ============================================================================
-- RPCs (funciones) se mantienen en sus archivos de módulo:
-- - 07_professional_profile_rpc.sql  -> perfil (update_professional_profile, etc.)
-- - 07_professional_public_rpc.sql   -> público (get_public_professionals, get_professional_public_detail, etc.)
-- Este archivo es SOLO un patch de esquema (columnas + slug helper + trigger).
-- ============================================================================