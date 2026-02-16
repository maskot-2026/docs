-- Content from legal_rpc.sql
-- ============================================================================
-- MasKot | Legal Module (legal_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Generar número de reclamo único
CREATE OR REPLACE FUNCTION generate_complaint_number()
RETURNS TEXT AS $$
DECLARE
    v_year TEXT;
    v_count INTEGER;
BEGIN
    v_year := TO_CHAR(NOW(), 'YYYY');
    SELECT COUNT(*) + 1 INTO v_count
    FROM complaints
    WHERE TO_CHAR(created_at, 'YYYY') = v_year;
    
    RETURN 'LR-' || v_year || '-' || LPAD(v_count::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear reclamo completo con generación de PDF
CREATE OR REPLACE FUNCTION create_complaint(p_complaint_data JSONB)
RETURNS JSONB AS $$
DECLARE
    v_complaint_number TEXT;
    v_complaint_id BIGINT;
BEGIN
    -- Generar número único
    v_complaint_number := generate_complaint_number();
    
    -- Crear reclamo
    INSERT INTO complaints (
        complaint_number, type, 
        consumer_document_type, consumer_document_number,
        consumer_name, consumer_email, consumer_phone, consumer_address,
        product_description, complaint_detail, consumer_request
    )
    VALUES (
        v_complaint_number,
        (p_complaint_data->>'type')::complaint_type,
        (p_complaint_data->>'consumer_document_type')::document_type,
        p_complaint_data->>'consumer_document_number',
        p_complaint_data->>'consumer_name',
        p_complaint_data->>'consumer_email',
        p_complaint_data->>'consumer_phone',
        p_complaint_data->>'consumer_address',
        p_complaint_data->>'product_description',
        p_complaint_data->>'complaint_detail',
        p_complaint_data->>'consumer_request'
    )
    RETURNING id INTO v_complaint_id;
    
    -- TODO: Generar PDF (integración con servicio externo)
    
    RETURN jsonb_build_object(
        'complaint_id', v_complaint_id,
        'complaint_number', v_complaint_number
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



