-- ============================================================================
-- MassKot | Legal & Compliance Module (04_legal_compliance_rls.sql)
-- Phase 3: RLS Policies & Security
-- ============================================================================

ALTER TABLE content_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE claims ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 1. Content Pages (Páginas Legales: Términos, Políticas)
-- ----------------------------------------------------------------------------
-- Lectura pública (solo publicadas)
DROP POLICY IF EXISTS "content_pages_select_public" ON content_pages;
CREATE POLICY "content_pages_select_public" ON content_pages
    FOR SELECT USING (is_active = true);

-- CRUD completo para Administradores
DROP POLICY IF EXISTS "content_pages_all_admin" ON content_pages;
CREATE POLICY "content_pages_all_admin" ON content_pages
    FOR ALL USING (auth_has_role('admin'));


-- ----------------------------------------------------------------------------
-- 2. Libro de Reclamaciones (Claims)
-- ----------------------------------------------------------------------------
-- INSERT: Público. Cualquier usuario puede enviar un reclamo (incluso guest).
-- CUIDADO DE COLUMNA: Evitamos que envíen 'response' o se cambien el status.
DROP POLICY IF EXISTS "claims_insert_public" ON claims;
CREATE POLICY "claims_insert_public" ON claims
    FOR INSERT WITH CHECK (
        response IS NULL AND 
        status = 'pending' AND 
        responded_at IS NULL
    );

-- CRUD completo para Administradores
DROP POLICY IF EXISTS "claims_all_admin" ON claims;
CREATE POLICY "claims_all_admin" ON claims
    FOR ALL USING (auth_has_role('admin'));

-- ============================================================================
-- RPC: Comprobación de reclamo por parte del Creador (Guest)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_my_claim_status(p_ticket_number TEXT, p_doc_number TEXT)
RETURNS JSONB AS $$
DECLARE
    v_claim RECORD;
BEGIN
    SELECT * INTO v_claim FROM claims 
    WHERE ticket_number = p_ticket_number AND doc_number = p_doc_number;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Claim not found');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'ticket_number', v_claim.ticket_number,
        'status', v_claim.status,
        'created_at', v_claim.created_at,
        'response', v_claim.response,
        'responded_at', v_claim.responded_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
