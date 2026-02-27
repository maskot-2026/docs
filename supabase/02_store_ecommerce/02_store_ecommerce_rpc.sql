-- Content from store_rpc.sql
-- ============================================================================
-- MasKot | Store Module (store_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Calcular totales del carrito con envío y validación de cupones integrada
CREATE OR REPLACE FUNCTION calculate_cart_totals(
    p_cart_id BIGINT,
    p_district TEXT,
    p_coupon_code TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_cart RECORD;
    v_subtotal NUMERIC := 0;
    v_shipping RECORD;
    v_shipping_cost NUMERIC := 0;
    v_delivery_days INTEGER := 1;
    v_discount NUMERIC := 0;
    v_coupon RECORD;
    v_has_free_shipping BOOLEAN := FALSE;
    v_item JSONB;
    v_coupon_error TEXT := NULL;
    v_valid_coupon_id BIGINT := NULL;
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
    IF p_district IS NOT NULL AND p_district != '' THEN
        SELECT * INTO v_shipping FROM shipping_zones 
        WHERE district = p_district AND is_active = TRUE
        LIMIT 1;
        
        IF v_shipping IS NOT NULL THEN
            v_shipping_cost := v_shipping.shipping_cost;
            v_delivery_days := v_shipping.delivery_days;
        END IF;
    END IF;

    -- Validar cupón ingresado (si existe)
    IF p_coupon_code IS NOT NULL AND TRIM(p_coupon_code) != '' THEN
        SELECT * INTO v_coupon FROM coupons
        WHERE code = UPPER(TRIM(p_coupon_code))
          AND is_active = TRUE
          AND valid_from <= NOW()
          AND (valid_until IS NULL OR valid_until >= NOW())
          AND (max_uses IS NULL OR used_count < max_uses);
          
        IF v_coupon IS NULL THEN
            v_coupon_error := 'Cupón no válido o expirado.';
        ELSIF v_coupon.min_order IS NOT NULL AND v_subtotal < v_coupon.min_order THEN
             -- Rechazar silenciosamente el cupón sin aplicarlo
            v_coupon_error := 'El subtotal debe ser mayor a S/. ' || v_coupon.min_order::TEXT || ' para aplicar este cupón.';
        ELSE
            -- El cupón es perfecto, retener ID y calcular descuentos
            v_valid_coupon_id := v_coupon.id;
            
            IF v_coupon.type::TEXT = 'percentage' THEN
                v_discount := v_subtotal * (v_coupon.value / 100);
            ELSIF v_coupon.type::TEXT = 'fixed_amount' THEN
                v_discount := v_coupon.value;
            ELSIF v_coupon.type::TEXT = 'free_shipping' THEN
                v_shipping_cost := 0;
                v_has_free_shipping := TRUE;
            END IF;
        END IF;
    END IF;
    
    -- Sincronizar el carrito en la base de datos de manera atómica (Aplica o Des-aplica el cupón real)
    UPDATE carts SET coupon_id = v_valid_coupon_id, updated_at = NOW() WHERE id = p_cart_id;

    RETURN jsonb_build_object(
        'subtotal', ROUND(v_subtotal, 2),
        'shipping_cost', ROUND(v_shipping_cost, 2),
        'discount', ROUND(v_discount, 2),
        'total', GREATEST(0, ROUND(v_subtotal + v_shipping_cost - v_discount, 2)),
        'delivery_days', v_delivery_days,
        'has_free_shipping', v_has_free_shipping,
        'coupon_error', v_coupon_error,
        'applied_coupon', CASE WHEN v_valid_coupon_id IS NOT NULL THEN UPPER(TRIM(p_coupon_code)) ELSE NULL END
    );
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;
