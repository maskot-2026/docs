-- Content from cms_rpc.sql
-- ============================================================================
-- MasKot | CMS Module (cms_rpc.sql)
-- RPC Implementations - Phase 1 Declarations Only
-- ============================================================================

-- RPC: Calcular ahorro proyectado según peso y edad (usado en slider interactivo)
CREATE OR REPLACE FUNCTION calculate_cost_savings(
    p_pet_weight_kg NUMERIC,
    p_pet_age_months INTEGER
) RETURNS JSONB AS $$
DECLARE
    v_monthly_traditional NUMERIC;
    v_monthly_maskot NUMERIC;
    v_daily_grams NUMERIC;
BEGIN
    -- Calcular gramos diarios basado en peso (fórmula simplificada)
    v_daily_grams := (p_pet_weight_kg * 20) + 50;
    
    -- Costo mensual comida tradicional (promedio mercado peruano)
    v_monthly_traditional := (v_daily_grams * 30 / 1000) * 35; -- S/.35/kg promedio
    
    -- Costo mensual MasKot (precio directo)
    v_monthly_maskot := (v_daily_grams * 30 / 1000) * 25; -- S/.25/kg MasKot
    
    RETURN jsonb_build_object(
        'monthly_traditional', ROUND(v_monthly_traditional, 2),
        'monthly_maskot', ROUND(v_monthly_maskot, 2),
        'savings_monthly', ROUND(v_monthly_traditional - v_monthly_maskot, 2),
        'savings_yearly', ROUND((v_monthly_traditional - v_monthly_maskot) * 12, 2),
        'savings_pct', ROUND(((v_monthly_traditional - v_monthly_maskot) / v_monthly_traditional) * 100, 1)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;



