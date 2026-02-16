-- Content from pets_rpc.sql
-- ============================================================================
-- MasKot | Pets Module (pets_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Generar reporte de diagnóstico completo
CREATE OR REPLACE FUNCTION generate_diagnostic_report(p_quiz_session_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    v_session RECORD;
    v_nutrition JSONB;
    v_products JSONB;
BEGIN
    -- Obtener sesión del quiz
    SELECT * INTO v_session FROM quiz_sessions WHERE id = p_quiz_session_id;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('error', 'Quiz session not found');
    END IF;
    
    -- Calcular nutrición
    v_nutrition := calculate_pet_nutrition(v_session.answers);
    
    RETURN jsonb_build_object(
        'pet_summary', jsonb_build_object(
            'pet_type', v_session.pet_type,
            'name', v_session.answers->>'pet_name',
            'weight_kg', v_session.answers->>'weight_kg',
            'activity_level', v_session.answers->>'activity_level'
        ),
        'nutrition_requirements', v_nutrition,
        'savings_comparison', jsonb_build_object(
            'monthly_traditional', 150,
            'monthly_maskot', 100,
            'savings_monthly', 50
        ),
        'nutrition_score', 85
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- RPC: Guardar perfil de mascota desde quiz (requiere auth)
CREATE OR REPLACE FUNCTION save_pet_profile_from_quiz(
    p_quiz_session_id BIGINT,
    p_pet_name TEXT
) RETURNS BIGINT AS $$
DECLARE
    v_session RECORD;
    v_pet_profile_id BIGINT;
    v_nutrition JSONB;
BEGIN
    -- Verificar autenticación
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;
    
    -- Obtener sesión del quiz
    SELECT * INTO v_session FROM quiz_sessions WHERE id = p_quiz_session_id;
    
    -- Calcular nutrición
    v_nutrition := calculate_pet_nutrition(v_session.answers);
    
    -- Crear perfil de mascota
    INSERT INTO pet_profiles (
        user_id, name, pet_type, weight_kg, activity_level, 
        health_conditions, daily_kcal_requirement
    )
    VALUES (
        auth.uid(),
        p_pet_name,
        v_session.pet_type,
        (v_session.answers->>'weight_kg')::NUMERIC,
        (v_session.answers->>'activity_level')::activity_level,
        ARRAY(SELECT jsonb_array_elements_text(v_session.answers->'health_conditions')::BIGINT),
        (v_nutrition->>'daily_kcal')::INTEGER
    )
    RETURNING id INTO v_pet_profile_id;
    
    -- Marcar sesión como completada
    UPDATE quiz_sessions SET completed_at = NOW(), user_id = auth.uid() 
    WHERE id = p_quiz_session_id;
    
    RETURN v_pet_profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Content from quiz_rpc.sql
-- ============================================================================
-- MasKot | Quiz Module (quiz_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Calcular nutrición basada en respuestas del quiz
CREATE OR REPLACE FUNCTION calculate_pet_nutrition(p_quiz_answers JSONB)
RETURNS JSONB AS $$
DECLARE
    v_weight_kg NUMERIC;
    v_rer NUMERIC;
    v_mer NUMERIC;
    v_activity_factor NUMERIC;
    v_excluded_ingredients TEXT[];
    v_health_conditions BIGINT[];
BEGIN
    v_weight_kg := (p_quiz_answers->>'weight_kg')::NUMERIC;
    v_health_conditions := ARRAY(SELECT jsonb_array_elements_text(p_quiz_answers->'health_conditions')::BIGINT);
    
    -- RER = 70 * (peso^0.75) - Fórmula estándar veterinaria
    v_rer := 70 * POWER(v_weight_kg, 0.75);
    
    -- MER = RER * factor actividad
    v_activity_factor := CASE p_quiz_answers->>'activity_level'
        WHEN 'sedentary' THEN 1.2
        WHEN 'moderate' THEN 1.4
        WHEN 'active' THEN 1.6
        WHEN 'very_active' THEN 1.8
        ELSE 1.4
    END;
    v_mer := v_rer * v_activity_factor;
    
    -- Obtener ingredientes excluidos por condiciones de salud
    SELECT ARRAY_AGG(DISTINCT unnest)
    INTO v_excluded_ingredients
    FROM health_conditions, UNNEST(excluded_ingredients)
    WHERE id = ANY(v_health_conditions);
    
    RETURN jsonb_build_object(
        'daily_kcal', ROUND(v_mer),
        'rer', ROUND(v_rer),
        'mer', ROUND(v_mer),
        'activity_factor', v_activity_factor,
        'excluded_ingredients', COALESCE(v_excluded_ingredients, '{}')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Obtener productos recomendados con score de compatibilidad
CREATE OR REPLACE FUNCTION get_recommended_products(
    p_pet_profile_id BIGINT,
    p_limit INTEGER DEFAULT 10
) RETURNS JSONB AS $$
DECLARE
    v_pet_profile RECORD;
    v_excluded TEXT[];
    v_result JSONB;
BEGIN
    -- Obtener perfil de mascota
    SELECT * INTO v_pet_profile FROM pet_profiles WHERE id = p_pet_profile_id;
    
    -- Obtener ingredientes a excluir
    SELECT ARRAY_AGG(DISTINCT unnest)
    INTO v_excluded
    FROM health_conditions, UNNEST(excluded_ingredients)
    WHERE id = ANY(v_pet_profile.health_conditions);
    
    -- Buscar productos compatibles
    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', p.id,
            'name', p.name,
            'price', p.price,
            'match_score', 85, -- TODO: Implementar algoritmo real
            'is_compatible', true
        )
    )
    INTO v_result
    FROM products p
    WHERE p.status = 'active'
      AND p.pet_type = v_pet_profile.pet_type
      AND NOT (p.excluded_ingredients && v_excluded)
    LIMIT p_limit;
    
    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;



