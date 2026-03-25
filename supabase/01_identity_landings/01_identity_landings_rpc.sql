-- ============================================================================
-- MassKot | CMS Module (cms_rpc.sql)
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
    v_masskot_kcal_per_g NUMERIC;

    -- Precios por KG
    v_traditional_price_per_kg NUMERIC;
    v_masskot_price_per_kg NUMERIC;

    v_daily_grams_traditional NUMERIC;
    -- Variables cálculo final
    v_monthly_traditional NUMERIC;
    v_monthly_masskot NUMERIC;
    v_savings_monthly NUMERIC;
    v_savings_yearly NUMERIC;
    v_savings_pct NUMERIC;
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
        v_traditional_kcal_per_g := 3.5;  -- Promedio croqueta gato
        v_masskot_kcal_per_g := 4.2;       -- Alimento natural gato (más denso)
        v_traditional_price_per_kg := 25.00; -- S/ 25/kg (Premium comercial)
        v_masskot_price_per_kg := 32.00;      -- S/ 32/kg (tu producto gato)
    ELSE
        v_traditional_kcal_per_g := 3.2;  -- Promedio croqueta perro
        v_masskot_kcal_per_g := 4.0;       -- Alimento natural perro
        v_traditional_price_per_kg := 22.00; -- S/ 22/kg (Premium comercial)
        v_masskot_price_per_kg := 28.50;      -- S/ 28.50/kg (tu producto perro)
    END IF;

    -- 5. Calcular gramos diarios necesarios para dieta MassKot
    v_daily_grams := v_mer / v_masskot_kcal_per_g;
    v_daily_grams_traditional := v_mer / v_traditional_kcal_per_g;

    -- =========================================================================
    -- 5. Calcular costos mensuales
    -- =========================================================================
    v_monthly_masskot := ROUND((v_daily_grams * 30 / 1000) * v_masskot_price_per_kg, 2);

    -- Regla de negocio: Ticket mínimo S/ 30.00
    -- (Ej: gatos muy pequeños o perros miniatura)
    v_monthly_masskot := GREATEST(v_monthly_masskot, 30.00);

    -- 8. Costo mensual tradicional
    -- Se asume p.ej. 20% más volumen diario debido a menor densidad calórica y fillers.
    v_monthly_traditional := ROUND((v_daily_grams * 1.2 * 30 / 1000) * v_traditional_price_per_kg, 2);

    v_savings_monthly := ROUND(v_monthly_traditional - v_monthly_masskot, 2);

    -- Regla de negocio: Asegurar que siempre se muestre un "ahorro"
    -- Si el tradicional da menor precio que MassKot, ajustamos el tradicional para fines de marketing:
    IF v_savings_monthly <= 0 THEN
        v_monthly_traditional := ROUND(v_monthly_masskot * 1.12, 2);
        v_savings_monthly := ROUND(v_monthly_traditional - v_monthly_masskot, 2);
    END IF;

    v_savings_yearly := v_savings_monthly * 12;
    v_savings_pct := ROUND((v_savings_monthly / v_monthly_traditional) * 100, 2);

    -- 9. Devolver el JSON final
    RETURN jsonb_build_object(
        'life_stage', v_life_stage,
        'daily_calories', ROUND(v_mer, 0),
        'daily_grams', ROUND(v_daily_grams, 0),
        'monthly_traditional', v_monthly_traditional,
        'monthly_masskot', v_monthly_masskot,
        'savings_monthly', v_savings_monthly,
        'savings_yearly', v_savings_yearly,
        'savings_pct', v_savings_pct,
        'cost_per_day_traditional', ROUND(v_monthly_traditional / 30, 2),
        'cost_per_day_masskot', ROUND(v_monthly_masskot / 30, 2)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
