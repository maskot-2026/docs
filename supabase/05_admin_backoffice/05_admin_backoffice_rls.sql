-- ============================================================================
-- MasKot | Admin Backoffice Module (05_admin_backoffice_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

-- Nota: Este módulo estructuralmente no posee tablas propias exclusivas,
-- dado que consume datos interdimensionales (ventas de e-commerce, usuarios de identidad, etc)
-- y depende fuertemente de los RPCs definidos en Fase 2 (get_reports_overview, etc).
-- Esos RPCs ya fueron creados con `SECURITY DEFINER` (para leer sin importar RLS)
-- pero DEBEN incluir una regla que obligue a ser Admin o rechazar.

-- Modificación sugerida de un RPC admin existente para incluir Auth Check forzado:
-- CREATE OR REPLACE FUNCTION get_reports_overview(p_date_from TIMESTAMPTZ, p_date_to TIMESTAMPTZ) RETURNS JSONB AS $$
-- BEGIN
--     IF NOT auth_has_role('admin') THEN
--         RAISE EXCEPTION 'Solo administradores pueden ver los reportes';
--     END IF;
--     -- lógica ...
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;
