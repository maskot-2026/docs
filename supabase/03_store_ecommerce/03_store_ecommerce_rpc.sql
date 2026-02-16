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



