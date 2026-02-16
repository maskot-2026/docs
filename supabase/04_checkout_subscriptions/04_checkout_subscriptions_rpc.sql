-- Content from orders_rpc.sql
-- ============================================================================
-- MasKot | Orders Module (orders_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Generar número de orden único
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
    v_date TEXT;
    v_sequence TEXT;
BEGIN
    v_date := TO_CHAR(NOW(), 'YYYYMMDD');
    v_sequence := LPAD(FLOOR(RANDOM() * 999999 + 1)::TEXT, 6, '0');
    RETURN 'MK-' || v_date || '-' || v_sequence;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear orden completa (transacción multi-tabla)
CREATE OR REPLACE FUNCTION create_order(
    p_user_id UUID,
    p_cart_id BIGINT,
    p_shipping_address_id BIGINT,
    p_payment_method payment_method,
    p_payment_token_id BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_cart RECORD;
    v_order_id BIGINT;
    v_order_number TEXT;
    v_totals JSONB;
    v_item JSONB;
    v_shipping RECORD;
BEGIN
    -- Verificar autenticación
    IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;
    
    -- Obtener carrito
    SELECT * INTO v_cart FROM carts WHERE id = p_cart_id AND user_id = p_user_id;
    IF v_cart IS NULL THEN
        RETURN jsonb_build_object('error', 'Carrito no encontrado');
    END IF;
    
    -- Obtener dirección de envío
    SELECT * INTO v_shipping FROM shipping_addresses 
    WHERE id = p_shipping_address_id AND user_id = p_user_id;
    IF v_shipping IS NULL THEN
        RETURN jsonb_build_object('error', 'Dirección no encontrada');
    END IF;
    
    -- Calcular totales
    v_totals := calculate_cart_totals(p_cart_id, v_shipping.district);
    
    -- Generar número de orden
    v_order_number := generate_order_number();
    
    -- Crear orden
    INSERT INTO orders (
        order_number, user_id, subtotal, discount, shipping_cost, total,
        shipping_address, payment_method, payment_status
    )
    VALUES (
        v_order_number,
        p_user_id,
        (v_totals->>'subtotal')::NUMERIC,
        (v_totals->>'discount')::NUMERIC,
        (v_totals->>'shipping_cost')::NUMERIC,
        (v_totals->>'total')::NUMERIC,
        to_jsonb(v_shipping),
        p_payment_method,
        'pending'
    )
    RETURNING id INTO v_order_id;
    
    -- Crear items de orden
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart.items)
    LOOP
        INSERT INTO order_items (order_id, product_id, variant_info, quantity, unit_price, is_subscription)
        VALUES (
            v_order_id,
            (v_item->>'product_id')::BIGINT,
            v_item->'variant_info',
            (v_item->>'quantity')::INTEGER,
            (v_item->>'price')::NUMERIC,
            COALESCE((v_item->>'is_subscription')::BOOLEAN, FALSE)
        );
        
        -- Decrementar stock
        UPDATE products SET stock_quantity = stock_quantity - (v_item->>'quantity')::INTEGER
        WHERE id = (v_item->>'product_id')::BIGINT;
    END LOOP;
    
    -- Limpiar carrito
    DELETE FROM carts WHERE id = p_cart_id;
    
    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'total', v_totals->>'total'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Actualizar estado de orden con historial
CREATE OR REPLACE FUNCTION update_order_status(
    p_order_id BIGINT,
    p_new_status order_status,
    p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
BEGIN
    -- Actualizar orden
    UPDATE orders SET status = p_new_status, updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Registrar en historial
    INSERT INTO order_status_history (order_id, status, notes, created_by)
    VALUES (p_order_id, p_new_status, p_notes, auth.uid());
    
    RETURN jsonb_build_object('success', true, 'order_id', p_order_id, 'new_status', p_new_status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Agregar tracking de envío
CREATE OR REPLACE FUNCTION add_order_shipment(
    p_order_id BIGINT,
    p_carrier TEXT,
    p_tracking_number TEXT
) RETURNS JSONB AS $$
DECLARE
    v_shipment_id BIGINT;
BEGIN
    -- Crear registro de envío
    INSERT INTO order_shipments (order_id, carrier, tracking_number, shipped_at)
    VALUES (p_order_id, p_carrier, p_tracking_number, NOW())
    RETURNING id INTO v_shipment_id;
    
    -- Actualizar estado de orden
    PERFORM update_order_status(p_order_id, 'shipped', 'Enviado con ' || p_carrier);
    
    RETURN jsonb_build_object('shipment_id', v_shipment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Content from subscriptions_rpc.sql
-- ============================================================================
-- MasKot | Subscriptions Module (subscriptions_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Pausar suscripción (máx 2 meses)
CREATE OR REPLACE FUNCTION pause_subscription(
    p_subscription_id BIGINT,
    p_pause_days INTEGER DEFAULT 30
) RETURNS JSONB AS $$
DECLARE
    v_subscription RECORD;
    v_pause_until TIMESTAMPTZ;
BEGIN
    -- Validar máximo 60 días
    IF p_pause_days > 60 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Máximo 60 días de pausa');
    END IF;
    
    -- Obtener suscripción
    SELECT * INTO v_subscription FROM subscriptions 
    WHERE id = p_subscription_id AND user_id = auth.uid();
    
    IF v_subscription IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Suscripción no encontrada');
    END IF;
    
    IF v_subscription.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden pausar suscripciones activas');
    END IF;
    
    v_pause_until := NOW() + (p_pause_days || ' days')::INTERVAL;
    
    -- Actualizar suscripción
    UPDATE subscriptions 
    SET status = 'paused', pause_until = v_pause_until, updated_at = NOW()
    WHERE id = p_subscription_id;
    
    -- Registrar en historial
    INSERT INTO subscription_history (subscription_id, action, details)
    VALUES (p_subscription_id, 'paused', jsonb_build_object('pause_days', p_pause_days, 'pause_until', v_pause_until));
    
    RETURN jsonb_build_object('success', true, 'new_status', 'paused', 'pause_until', v_pause_until);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Reanudar suscripción
CREATE OR REPLACE FUNCTION resume_subscription(p_subscription_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    v_subscription RECORD;
    v_next_billing TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_subscription FROM subscriptions 
    WHERE id = p_subscription_id AND user_id = auth.uid();
    
    IF v_subscription IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Suscripción no encontrada');
    END IF;
    
    IF v_subscription.status != 'paused' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden reanudar suscripciones pausadas');
    END IF;
    
    v_next_billing := NOW() + (v_subscription.frequency_days || ' days')::INTERVAL;
    
    UPDATE subscriptions 
    SET status = 'active', pause_until = NULL, next_billing_date = v_next_billing, updated_at = NOW()
    WHERE id = p_subscription_id;
    
    INSERT INTO subscription_history (subscription_id, action, details)
    VALUES (p_subscription_id, 'resumed', jsonb_build_object('next_billing_date', v_next_billing));
    
    RETURN jsonb_build_object('success', true, 'new_status', 'active', 'next_billing_date', v_next_billing);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Cancelar suscripción con motivo
CREATE OR REPLACE FUNCTION cancel_subscription(
    p_subscription_id BIGINT,
    p_cancellation_reason TEXT
) RETURNS JSONB AS $$
DECLARE
    v_subscription RECORD;
BEGIN
    SELECT * INTO v_subscription FROM subscriptions 
    WHERE id = p_subscription_id AND user_id = auth.uid();
    
    IF v_subscription IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Suscripción no encontrada');
    END IF;
    
    UPDATE subscriptions 
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_subscription_id;
    
    INSERT INTO subscription_history (subscription_id, action, details)
    VALUES (p_subscription_id, 'cancelled', jsonb_build_object('reason', p_cancellation_reason));
    
    RETURN jsonb_build_object('success', true, 'cancelled_at', NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Adelantar próximo envío
CREATE OR REPLACE FUNCTION advance_next_shipment(p_subscription_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    v_subscription RECORD;
    v_new_date TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_subscription FROM subscriptions 
    WHERE id = p_subscription_id AND user_id = auth.uid();
    
    IF v_subscription IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Suscripción no encontrada');
    END IF;
    
    v_new_date := NOW() + INTERVAL '2 days'; -- Procesar en 2 días
    
    UPDATE subscriptions 
    SET next_billing_date = v_new_date, updated_at = NOW()
    WHERE id = p_subscription_id;
    
    RETURN jsonb_build_object('success', true, 'new_next_billing_date', v_new_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



