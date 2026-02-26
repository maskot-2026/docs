-- ============================================================================
-- MasKot | CMS Module (cms_rpc.sql)
-- RPC: Calculadora Nutricional Definitiva con Fórmula RER Veterinaria
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_cost_savings(
    p_pet_weight_kg NUMERIC,
    p_pet_age_months INTEGER,
    p_activity_level TEXT DEFAULT 'normal',    -- 'sedentary' | 'normal' | 'active' | 'very_active'
    p_is_neutered BOOLEAN DEFAULT FALSE,
    p_body_condition TEXT DEFAULT 'ideal',     -- 'underweight' | 'ideal' | 'overweight'
    p_pet_type TEXT DEFAULT 'dog'              -- 'dog' | 'cat'
) RETURNS JSONB AS $$
DECLARE
    v_rer NUMERIC;           -- Resting Energy Requirement (Kcal/día)
    v_mer_factor NUMERIC;    -- Factor de mantenimiento energético
    v_mer NUMERIC;           -- Maintenance Energy Requirement (Kcal/día)
    v_daily_grams NUMERIC;
    v_life_stage TEXT;

    -- Densidad calórica (Kcal por gramo)
    v_traditional_kcal_per_g NUMERIC;
    v_maskot_kcal_per_g NUMERIC;

    -- Precios por Kg (mercado peruano)
    v_traditional_price_per_kg NUMERIC;
    v_maskot_price_per_kg NUMERIC;

    v_daily_grams_traditional NUMERIC;
    v_monthly_traditional NUMERIC;
    v_monthly_maskot NUMERIC;
    v_savings_monthly NUMERIC;
BEGIN
    -- =========================================================================
    -- 1. RER: Fórmula veterinaria estándar (NRC 2006)
    --    RER = 70 × (peso_kg ^ 0.75)
    -- =========================================================================
    IF p_pet_type = 'cat' THEN
        v_rer := 70 * POWER(p_pet_weight_kg, 0.67); -- Gatos usan exponente 0.67
    ELSE
        v_rer := 70 * POWER(p_pet_weight_kg, 0.75); -- Perros usan exponente 0.75
    END IF;

    -- =========================================================================
    -- 2. Determinar el factor MER según etapa de vida
    -- =========================================================================
    IF p_pet_type = 'cat' THEN
        -- Factores para GATOS
        IF p_pet_age_months <= 4 THEN
            v_life_stage := 'Gatito (crecimiento)';
            v_mer_factor := 2.5;
        ELSIF p_pet_age_months <= 12 THEN
            v_life_stage := 'Gato joven';
            v_mer_factor := 2.0;
        ELSIF p_pet_age_months <= 84 THEN
            v_life_stage := 'Gato adulto';
            v_mer_factor := 1.4;
        ELSE
            v_life_stage := 'Gato senior';
            v_mer_factor := 1.1;
        END IF;
    ELSE
        -- Factores para PERROS
        IF p_pet_age_months <= 4 THEN
            v_life_stage := 'Cachorro (crecimiento rápido)';
            v_mer_factor := 3.0;
        ELSIF p_pet_age_months <= 12 THEN
            v_life_stage := 'Cachorro joven';
            v_mer_factor := 2.0;
        ELSIF p_pet_age_months <= 84 THEN
            v_life_stage := 'Adulto';
            v_mer_factor := 1.6;
        ELSE
            v_life_stage := 'Senior';
            v_mer_factor := 1.2;
        END IF;
    END IF;

    -- =========================================================================
    -- 3. Ajustes de factor MER por condiciones adicionales
    -- =========================================================================

    -- Ajuste por esterilización (reduce necesidad ~20%)
    IF p_is_neutered THEN
        v_mer_factor := v_mer_factor * 0.80;
    END IF;

    -- Ajuste por nivel de actividad
    CASE p_activity_level
        WHEN 'sedentary'   THEN v_mer_factor := v_mer_factor * 0.85;
        WHEN 'normal'      THEN NULL; -- Sin cambio
        WHEN 'active'      THEN v_mer_factor := v_mer_factor * 1.25;
        WHEN 'very_active'  THEN v_mer_factor := v_mer_factor * 1.50;
        ELSE NULL;
    END CASE;

    -- Ajuste por condición corporal
    CASE p_body_condition
        WHEN 'underweight' THEN v_mer_factor := v_mer_factor * 1.20; -- +20% para ganar peso
        WHEN 'ideal'       THEN NULL;
        WHEN 'overweight'  THEN v_mer_factor := v_mer_factor * 0.80; -- -20% para perder peso
        ELSE NULL;
    END CASE;

    -- =========================================================================
    -- 4. Calcular MER y gramos diarios
    -- =========================================================================
    v_mer := v_rer * v_mer_factor;

    -- Densidad calórica por tipo de alimento (Kcal/g)
    IF p_pet_type = 'cat' THEN
        v_traditional_kcal_per_g := 3.5;  -- Croqueta premium gato
        v_maskot_kcal_per_g := 4.2;       -- Alimento natural gato (más denso)
        v_traditional_price_per_kg := 45.00; -- S/ 45/kg (Royal Canin gato, ProPlan)
        v_maskot_price_per_kg := 32.00;      -- S/ 32/kg (tu producto gato)
    ELSE
        v_traditional_kcal_per_g := 3.8;  -- Croqueta super-premium perro
        v_maskot_kcal_per_g := 4.0;       -- Alimento natural perro
        v_traditional_price_per_kg := 38.00; -- S/ 38/kg (ProPlan, Royal Canin)
        v_maskot_price_per_kg := 28.50;      -- S/ 28.50/kg (tu producto perro)
    END IF;

    -- Gramos diarios = Kcal necesarias / Kcal por gramo
    v_daily_grams := v_mer / v_maskot_kcal_per_g;
    v_daily_grams_traditional := v_mer / v_traditional_kcal_per_g;

    -- =========================================================================
    -- 5. Calcular costos mensuales
    -- =========================================================================
    v_monthly_traditional := ROUND((v_daily_grams_traditional * 30 / 1000) * v_traditional_price_per_kg, 2);
    v_monthly_maskot := ROUND((v_daily_grams * 30 / 1000) * v_maskot_price_per_kg, 2);

    -- Pisos mínimos realistas
    v_monthly_traditional := GREATEST(v_monthly_traditional, 40.00);
    v_monthly_maskot := GREATEST(v_monthly_maskot, 30.00);

    -- =========================================================================
    -- 6. Cálculo final
    -- =========================================================================
    v_savings_monthly := ROUND(v_monthly_traditional - v_monthly_maskot, 2);

    -- Garantía comercial: siempre mostrar ahorro mínimo del 10%
    IF v_savings_monthly <= 0 THEN
        v_monthly_traditional := ROUND(v_monthly_maskot * 1.12, 2);
        v_savings_monthly := ROUND(v_monthly_traditional - v_monthly_maskot, 2);
    END IF;

    RETURN jsonb_build_object(
        'life_stage', v_life_stage,
        'daily_calories', ROUND(v_mer),
        'daily_grams', ROUND(v_daily_grams),
        'monthly_traditional', v_monthly_traditional,
        'monthly_maskot', v_monthly_maskot,
        'savings_monthly', v_savings_monthly,
        'savings_yearly', ROUND(v_savings_monthly * 12, 2),
        'savings_pct', ROUND((v_savings_monthly / v_monthly_traditional) * 100, 1),
        'cost_per_day_traditional', ROUND(v_monthly_traditional / 30, 2),
        'cost_per_day_maskot', ROUND(v_monthly_maskot / 30, 2)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;
