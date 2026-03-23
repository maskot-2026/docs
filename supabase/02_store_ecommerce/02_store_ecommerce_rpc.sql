-- Content from store_rpc.sql
-- ============================================================================
-- MasKot | Store Module (store_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Calcular totales del carrito con envío y gestión de cupones
-- Este es el ÚNICO punto de entrada para cálculos de carrito.
--   p_district = NULL   → envío no calculado (S/. 0)
--   p_coupon_code = NULL → leer cupón guardado en carts.coupon_id
--   p_coupon_code = 'X'  → validar, guardar y aplicar cupón 'X'
CREATE OR REPLACE FUNCTION calculate_cart_totals(
    p_cart_id BIGINT,
    p_district TEXT DEFAULT NULL,
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
    v_applied_coupon_code TEXT := NULL;
    v_coupon_found BOOLEAN := FALSE;
BEGIN
    -- 1. Obtener carrito
    SELECT * INTO v_cart FROM carts WHERE id = p_cart_id;
    IF v_cart IS NULL THEN
        RAISE EXCEPTION 'Carrito no encontrado';
    END IF;

    -- 1.5 Validar propiedad del carrito (Si pertenece a un usuario, no permitir que otro lo lea)
    IF v_cart.profile_id IS NOT NULL AND auth.uid() IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_cart.profile_id AND user_id = auth.uid()) AND NOT auth_has_role('admin') THEN
            RAISE EXCEPTION 'No autorizado para calcular este carrito';
        END IF;
    ELSIF v_cart.profile_id IS NOT NULL AND auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Debe iniciar sesión para calcular este carrito';
    END IF;
    -- Los carritos de guest (profile_id IS NULL) son calculables públicamente asumiendo que el frontend controla el session_id

    -- 2. Calcular subtotal (solo items seleccionados, por defecto true)
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart.items)
    LOOP
        IF COALESCE((v_item->>'selected')::BOOLEAN, TRUE) = TRUE THEN
            v_subtotal := v_subtotal + ((v_item->>'price')::NUMERIC * (v_item->>'quantity')::INTEGER);
        END IF;
    END LOOP;

    -- 3. Calcular envío (si hay distrito)
    IF p_district IS NOT NULL AND p_district != '' THEN
        SELECT * INTO v_shipping FROM shipping_zones
        WHERE district = p_district AND is_active = TRUE
        LIMIT 1;
        IF v_shipping IS NOT NULL THEN
            v_shipping_cost := v_shipping.shipping_cost;
            v_delivery_days := v_shipping.delivery_days;
        END IF;
    END IF;

    -- 4. Gestión de cupón (DRY refactor)
    -- a. Determinar si intentamos aplicar un cupón nuevo o leer el guardado
    IF p_coupon_code IS NOT NULL THEN
        -- El usuario mandó explícitamente un código para aplicar
        SELECT * INTO v_coupon FROM coupons
        WHERE code = UPPER(TRIM(p_coupon_code))
          AND is_active = TRUE
          AND valid_from <= NOW()
          AND (valid_until IS NULL OR valid_until >= NOW())
          AND (max_uses IS NULL OR used_count < max_uses);

        IF FOUND THEN
            v_coupon_found := TRUE;
        ELSE
            v_coupon_error := 'Cupón no válido o expirado.';
        END IF;
    ELSIF v_cart.coupon_id IS NOT NULL THEN
        -- No mandó código, intentamos usar el que ya está guardado en el carrito
        SELECT * INTO v_coupon FROM coupons
        WHERE id = v_cart.coupon_id
          AND is_active = TRUE
          AND valid_from <= NOW()
          AND (valid_until IS NULL OR valid_until >= NOW())
          AND (max_uses IS NULL OR used_count < max_uses);

        IF FOUND THEN
            v_coupon_found := TRUE;
        ELSE
            v_coupon_error := 'El cupón aplicado ya no es válido.';
        END IF;
    END IF;

    -- b. Validar mínimo de orden y aplicar si todo está bien
    IF v_coupon_error IS NOT NULL THEN
        -- Falló la búsqueda inicial (por código o id)
        UPDATE carts SET coupon_id = NULL, updated_at = NOW() WHERE id = p_cart_id;
    ELSIF v_coupon_found THEN -- FOUND
        -- Encontramos un cupón candidato, validar mínimo
        IF v_coupon.min_order IS NOT NULL AND v_subtotal < v_coupon.min_order THEN
            v_coupon_error := 'El subtotal debe ser mayor a S/. ' || v_coupon.min_order::TEXT || ' para aplicar este cupón.';
            UPDATE carts SET coupon_id = NULL, updated_at = NOW() WHERE id = p_cart_id;
        ELSE
            -- Cupón 100% válido -> Guardar en carrito y calcular descuento
            v_applied_coupon_code := v_coupon.code;
            
            -- Solo hacer UPDATE si viene un nuevo código
            IF p_coupon_code IS NOT NULL THEN
                UPDATE carts SET coupon_id = v_coupon.id, updated_at = NOW() WHERE id = p_cart_id;
            END IF;

            IF v_coupon.type::TEXT = 'percentage' THEN
                v_discount := ROUND(v_subtotal * v_coupon.value / 100, 2);
            ELSIF v_coupon.type::TEXT = 'fixed_amount' THEN
                v_discount := LEAST(v_coupon.value, v_subtotal);
            ELSIF v_coupon.type::TEXT = 'free_shipping' THEN
                v_shipping_cost := 0;
                v_has_free_shipping := TRUE;
            END IF;
        END IF;
    END IF;

    -- 5. Retornar totales
    RETURN jsonb_build_object(
        'subtotal', ROUND(v_subtotal, 2),
        'shipping_cost', ROUND(v_shipping_cost, 2),
        'discount', ROUND(v_discount, 2),
        'total', GREATEST(0, ROUND(v_subtotal + v_shipping_cost - v_discount, 2)),
        'delivery_days', v_delivery_days,
        'has_free_shipping', v_has_free_shipping,
        'coupon_error', v_coupon_error,
        'applied_coupon', v_applied_coupon_code
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
