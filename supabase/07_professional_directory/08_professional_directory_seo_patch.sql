-- ============================================================================
-- MassKot | Professional Directory SEO & Contact Patch
-- Agrega campos para URLs amigables (slug), disponibilidad (is_available),
-- y WhatsApp (phone) a professional_profiles
--
-- ACTUALIZADO: 2026-06-02
-- Estos campos ahora también se agregan en 01_update_sql_professional_part1.sql
-- Este archivo se mantiene por compatibilidad con deployments anteriores.
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

-- 4. Agregar treated_conditions (texto libre para condiciones tratadas)
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS treated_conditions TEXT;

-- 5. Agregar average_rating y total_reviews si no existen
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS average_rating NUMERIC DEFAULT 0.00;

ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0;

-- 6. Agregar profile_photo_url y gallery_urls si no existen
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS gallery_urls TEXT[] DEFAULT '{}';

-- 7. Agregar consultation_types si no existe
ALTER TABLE IF EXISTS professional_profiles
  ADD COLUMN IF NOT EXISTS consultation_types TEXT[] DEFAULT '{}';

-- 8. Crear índice para búsqueda por slug
CREATE INDEX IF NOT EXISTS idx_professional_profiles_slug
  ON professional_profiles(slug) WHERE slug IS NOT NULL;

-- 9. Crear índice para buscar profesionales disponibles
CREATE INDEX IF NOT EXISTS idx_professional_profiles_available
  ON professional_profiles(status, is_published, is_available);

-- 10. Crear índice para rating
CREATE INDEX IF NOT EXISTS idx_professional_profiles_rating
  ON professional_profiles(average_rating DESC, total_reviews DESC);

-- 11. Función para generar slug desde public_name
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

-- 12. Trigger para auto-generar slug al crear perfil
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