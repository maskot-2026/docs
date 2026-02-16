-- Content from store_rpc.sql
-- ============================================================================
-- MasKot | Store Module (store_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Validar y aplicar cupón al carrito
CREATE OR REPLACE FUNCTION validate_and_apply_coupon(
    p_coupon_code TEXT,
    p_cart_subtotal NUMERIC
) RETURNS JSONB AS $$
DECLARE
    v_coupon RECORD;
    v_discount NUMERIC;
BEGIN
    -- Buscar cupón activo
    SELECT * INTO v_coupon FROM coupons
    WHERE code = UPPER(p_coupon_code)
      AND is_active = TRUE
      AND valid_from <= NOW()
      AND (valid_until IS NULL OR valid_until >= NOW())
      AND (max_uses IS NULL OR used_count < max_uses);
    
    IF v_coupon IS NULL THEN
        RETURN jsonb_build_object('valid', false, 'error_message', 'Cupón no válido o expirado');
    END IF;
    
    -- Verificar mínimo de orden
    IF v_coupon.min_order IS NOT NULL AND p_cart_subtotal < v_coupon.min_order THEN
        RETURN jsonb_build_object('valid', false, 'error_message', 
            'Mínimo de compra: S/.' || v_coupon.min_order::TEXT);
    END IF;
    
    -- Calcular descuento
    v_discount := CASE v_coupon.type
        WHEN 'percentage' THEN p_cart_subtotal * (v_coupon.value / 100)
        WHEN 'fixed_amount' THEN v_coupon.value
        WHEN 'free_shipping' THEN 0 -- Se aplica al envío
        ELSE 0
    END;
    
    RETURN jsonb_build_object(
        'valid', true,
        'coupon_id', v_coupon.id,
        'type', v_coupon.type,
        'discount_amount', ROUND(v_discount, 2)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- RPC: Calcular totales del carrito con envío y descuentos
CREATE OR REPLACE FUNCTION calculate_cart_totals(
    p_cart_id BIGINT,
    p_district TEXT
) RETURNS JSONB AS $$
DECLARE
    v_cart RECORD;
    v_subtotal NUMERIC := 0;
    v_shipping RECORD;
    v_discount NUMERIC := 0;
    v_coupon RECORD;
    v_item JSONB;
BEGIN
    -- Obtener carrito
    SELECT * INTO v_cart FROM carts WHERE id = p_cart_id;
    
    IF v_cart IS NULL THEN
        RETURN jsonb_build_object('error', 'Carrito no encontrado');
    END IF;
    
    -- Calcular subtotal
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart.items)
    LOOP
        v_subtotal := v_subtotal + ((v_item->>'price')::NUMERIC * (v_item->>'quantity')::INTEGER);
    END LOOP;
    
    -- Obtener costo de envío
    SELECT * INTO v_shipping FROM shipping_zones 
    WHERE district = p_district AND is_active = TRUE
    LIMIT 1;
    
    -- Aplicar descuento si hay cupón
    IF v_cart.coupon_id IS NOT NULL THEN
        SELECT * INTO v_coupon FROM coupons WHERE id = v_cart.coupon_id;
        v_discount := CASE v_coupon.type
            WHEN 'percentage' THEN v_subtotal * (v_coupon.value / 100)
            WHEN 'fixed_amount' THEN v_coupon.value
            ELSE 0
        END;
    END IF;
    
    RETURN jsonb_build_object(
        'subtotal', ROUND(v_subtotal, 2),
        'shipping_cost', COALESCE(v_shipping.shipping_cost, 15),
        'discount', ROUND(v_discount, 2),
        'total', ROUND(v_subtotal + COALESCE(v_shipping.shipping_cost, 15) - v_discount, 2),
        'delivery_days', COALESCE(v_shipping.delivery_days, 5)
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================================================
-- HU-2.4: Calculadora de Ración Diaria
-- ============================================================================

-- RPC: Calcular ración diaria según inputs del usuario
CREATE OR REPLACE FUNCTION calculate_daily_ration(
    p_weight_kg NUMERIC,
    p_age_years INTEGER,
    p_is_neutered BOOLEAN,
    p_body_condition TEXT,
    p_activity_level TEXT
) RETURNS JSONB AS $$
DECLARE
    v_rer NUMERIC;
    v_mer NUMERIC;
    v_activity_factor NUMERIC;
    v_daily_grams NUMERIC;
BEGIN
    -- Validar inputs
    IF p_weight_kg IS NULL OR p_weight_kg <= 0 THEN
        RETURN jsonb_build_object('error', 'Peso inválido');
    END IF;
    
    -- Paso 1: Calcular RER (Requerimiento Energético en Reposo)
    -- Fórmula: RER = 70 * (peso_kg^0.75)
    v_rer := 70 * POWER(p_weight_kg, 0.75);
    
    -- Paso 2: Determinar factor de actividad según nivel
    v_activity_factor := CASE p_activity_level
        WHEN 'bajo' THEN 1.2
        WHEN 'medio' THEN 1.4
        WHEN 'alto' THEN 1.6
        ELSE 1.4  -- Default: medio
    END;
    
    -- Paso 3: Ajuste por esterilización (-10% metabolismo)
    IF p_is_neutered THEN
        v_activity_factor := v_activity_factor * 0.9;
    END IF;
    
    -- Paso 4: Ajuste por condición corporal
    v_activity_factor := CASE p_body_condition
        WHEN 'delgado' THEN v_activity_factor * 1.1   -- +10% para ganar peso
        WHEN 'sobrepeso' THEN v_activity_factor * 0.9  -- -10% para perder peso
        ELSE v_activity_factor  -- 'ideal': sin ajuste
    END;
    
    -- Paso 5: Calcular MER (Mantenimiento Energético Requerido)
    v_mer := v_rer * v_activity_factor;
    
    -- Paso 6: Convertir kcal a gramos de alimento
    -- Asumiendo 350 kcal por cada 100g de alimento seco premium
    v_daily_grams := (v_mer / 350) * 100;
    
    -- Retornar resultado
    RETURN jsonb_build_object(
        'daily_kcal', ROUND(v_mer, 0),
        'daily_grams', ROUND(v_daily_grams, 0),
        'rer', ROUND(v_rer, 0),
        'activity_factor', ROUND(v_activity_factor, 2),
        'recommendation', CASE
            WHEN v_daily_grams < 100 THEN 'Consulta con veterinario para dosis precisas'
            WHEN v_daily_grams > 1000 THEN 'Considera dividir en 2-3 porciones diarias'
            ELSE 'Dividir en 2 porciones diarias'
        END
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;
