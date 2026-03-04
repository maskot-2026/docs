CREATE OR REPLACE FUNCTION create_order(
    p_cart_id BIGINT,
    p_shipping_address JSONB,          -- Inline snapshot: {recipient_name, phone, address_line1, address_line2, district, department}
    p_billing_profile JSONB,           -- Inline snapshot: {document_type, document_number, customer_name, fiscal_address}
    p_contact_email TEXT,
    p_profile_id BIGINT DEFAULT NULL,  -- NULL for guest checkout
    p_checkout_id TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_cart RECORD;
    v_order_id BIGINT;
    v_item JSONB;
    v_totals JSONB;
    v_subtotal NUMERIC;
    v_discount NUMERIC;
    v_shipping_cost NUMERIC;
    v_total NUMERIC;
    v_district TEXT;
BEGIN
    -- 1. Validar autenticación SOLO si se pasa un profile_id (Omitido auth.uid() para desarrollo)
    IF p_profile_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM profiles WHERE id = p_profile_id AND deleted_at IS NULL
        ) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Perfil no autorizado o no encontrado');
        END IF;
    END IF;

    -- 2. Validar Carrito
    IF p_profile_id IS NOT NULL THEN
        SELECT * INTO v_cart FROM carts WHERE id = p_cart_id AND profile_id = p_profile_id;
    ELSE
        SELECT * INTO v_cart FROM carts WHERE id = p_cart_id AND profile_id IS NULL;
    END IF;

    IF NOT FOUND OR jsonb_array_length(v_cart.items) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El carrito está vacío o no es válido');
    END IF;

    -- 3. Validar datos de envío y email
    IF p_shipping_address IS NULL OR p_shipping_address->>'district' IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dirección de envío incompleta');
    END IF;

    IF p_contact_email IS NULL OR p_contact_email = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Email de contacto es requerido');
    END IF;

    -- 4. Calcular totales usando calculate_cart_totals (single source of truth)
    v_district := p_shipping_address->>'district';
    v_totals := calculate_cart_totals(p_cart_id, v_district, NULL);

    -- Verificar error del RPC
    IF v_totals->>'error' IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', v_totals->>'error');
    END IF;

    v_subtotal := (v_totals->>'subtotal')::NUMERIC;
    v_discount := (v_totals->>'discount')::NUMERIC;
    v_shipping_cost := (v_totals->>'shipping_cost')::NUMERIC;
    v_total := (v_totals->>'total')::NUMERIC;

    -- 5. Incrementar used_count del cupón (si hay uno aplicado)
    IF v_cart.coupon_id IS NOT NULL AND v_totals->>'applied_coupon' IS NOT NULL THEN
        UPDATE coupons SET used_count = used_count + 1 WHERE id = v_cart.coupon_id;
    END IF;

    -- 6. Crear la orden central
    INSERT INTO orders (
        profile_id, status, subtotal, discount, shipping_cost, total,
        shipping_address, billing_profile, payment_status, contact_email, checkout_id
    ) VALUES (
        p_profile_id, 'pending', v_subtotal, v_discount, v_shipping_cost, v_total,
        p_shipping_address, COALESCE(p_billing_profile, '{}'::jsonb),
        'pending', p_contact_email, p_checkout_id
    ) RETURNING id INTO v_order_id;

    -- 7. Insertar items
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart.items)
    LOOP
        INSERT INTO order_items (
            order_id, product_id, product_name, variant_sku, variant_attributes,
            quantity, unit_price, is_subscription, subscription_frequency_days
        ) VALUES (
            v_order_id,
            (v_item->>'product_id')::BIGINT,
            v_item->>'name',
            v_item->>'variant_sku',
            COALESCE(v_item->'selected_variant', '{}'::jsonb),
            (v_item->>'quantity')::INTEGER,
            (v_item->>'price')::NUMERIC,
            COALESCE((v_item->>'is_subscription')::BOOLEAN, FALSE),
            (v_item->>'frequency_days')::INTEGER
        );
        -- Decrementar stock en el JSONB de variantes
        UPDATE products 
        SET variants = (
            SELECT jsonb_agg(
                CASE 
                    WHEN v->>'sku' = v_item->>'variant_sku' THEN 
                        jsonb_set(v, '{stock}', ((v->>'stock')::int - (v_item->>'quantity')::int)::text::jsonb)
                    ELSE v 
                END
            )
            FROM jsonb_array_elements(variants) AS v
        )
        WHERE id = (v_item->>'product_id')::BIGINT;
    END LOOP;

    -- 8. Limpiar Carrito
    UPDATE carts SET items = '[]'::jsonb, coupon_id = NULL, updated_at = NOW() WHERE id = p_cart_id;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'total', v_total
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Gestionar Estado de Suscripción (Status Controller)
-- Permite transicionar de manera segura el estado (active, paused, cancelled, expired)
-- y maneja los efectos secundarios (fechas de pausa/cobro). El historial es auto-generado por el Trigger.
-- ============================================================================
CREATE OR REPLACE FUNCTION manage_subscription_status(
    p_subscription_id BIGINT,
    p_new_status subscription_status,
    p_pause_days INTEGER DEFAULT NULL,
    p_cancel_reason TEXT DEFAULT NULL,
    p_charge_immediately BOOLEAN DEFAULT TRUE
) RETURNS JSONB AS $$
DECLARE
    v_sub RECORD;
    v_pause_until TIMESTAMPTZ := NULL;
BEGIN
    -- 1. Validar propiedad (Omitido auth.uid() para desarrollo)
    SELECT s.* INTO v_sub FROM subscriptions s
    WHERE s.id = p_subscription_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Suscripción no encontrada');
    END IF;

    -- Si el estado es el mismo, no hacer nada
    IF v_sub.status = p_new_status THEN
        RETURN jsonb_build_object('success', true, 'message', 'La suscripción ya se encuentra en ese estado');
    END IF;

    -- 2. Procesar transición de estado
    IF p_new_status = 'cancelled' THEN
        -- Cancelar (irreversible estructuralmente desde frontend por diseño seguro, pero permitimos reactivar manual)
        UPDATE subscriptions SET status = 'cancelled', cancel_reason = p_cancel_reason, updated_at = NOW() WHERE id = p_subscription_id;

    ELSIF p_new_status = 'paused' THEN
        -- Pausar
        IF v_sub.status != 'active' THEN
            RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden pausar suscripciones activas');
        END IF;

        IF p_pause_days IS NULL OR p_pause_days <= 0 OR p_pause_days > 60 THEN
            RETURN jsonb_build_object('success', false, 'error', 'Los días de pausa deben estar entre 1 y 60 días');
        END IF;

        v_pause_until := NOW() + (p_pause_days || ' days')::INTERVAL;

        UPDATE subscriptions 
        SET status = 'paused', 
            pause_until = v_pause_until,
            -- Al pausar, empujamos la fecha de cobro la misma cantidad de días
            next_billing_date = next_billing_date + (p_pause_days || ' days')::INTERVAL,
            updated_at = NOW() 
        WHERE id = p_subscription_id;

    ELSIF p_new_status = 'active' THEN
        -- Reanudar
        IF v_sub.status = 'past_due' THEN
            -- De past_due a active (Pago Recuperado exitosamente hoy)
            -- El ciclo se reinicia a partir de hoy para evitar overstocking
            UPDATE subscriptions 
            SET status = 'active', 
                next_billing_date = NOW() + (v_sub.frequency_days || ' days')::INTERVAL,
                cancel_reason = NULL,
                updated_at = NOW() 
            WHERE id = p_subscription_id;

        ELSIF v_sub.status = 'cancelled' THEN
            -- De cancelled a active (Reactivación manual con posible cobro inmediato)
            UPDATE subscriptions 
            SET status = 'active', 
                next_billing_date = CASE 
                    WHEN p_charge_immediately THEN NOW()
                    ELSE NOW() + (v_sub.frequency_days || ' days')::INTERVAL
                END,
                cancel_reason = NULL,
                updated_at = NOW() 
            WHERE id = p_subscription_id;

        ELSIF v_sub.status = 'paused' THEN
            -- De paused a active (Reanudación Voluntaria)
            -- Si ya pasó la fecha de cobro, cobrar hoy (CATCH UP). Si es futura, mantener.
            UPDATE subscriptions 
            SET status = 'active', 
                next_billing_date = GREATEST(next_billing_date, NOW()),
                pause_until = NULL, 
                cancel_reason = NULL,
                updated_at = NOW() 
            WHERE id = p_subscription_id;

        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden reanudar suscripciones pausadas, canceladas o vencidas (past_due)');
        END IF;

    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Transición de estado no soportada o prohibida');
    END IF;

    -- NOTA: No insertamos en `subscription_history` porque el trigger `trg_log_subscription_history` 
    -- detectará el UPDATE de la columna `status` y lo hará automáticamente.

    RETURN jsonb_build_object(
        'success', true, 
        'new_status', p_new_status,
        'pause_until', v_pause_until
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 5. TRIGGERS & AUTOMATION: Subscription History Logs
-- ============================================================================

-- Función Trigger para registrar historial de suscripciones de manera automática
CREATE OR REPLACE FUNCTION log_subscription_history()
RETURNS TRIGGER AS $$
DECLARE
    v_action subscription_action;
    v_details JSONB := '{}'::jsonb;
BEGIN
    -- Caso 1: Nueva Suscripción (INSERT)
    IF TG_OP = 'INSERT' THEN
        v_action := 'created';
        INSERT INTO subscription_history (subscription_id, action, details)
        VALUES (NEW.id, v_action, v_details);
        RETURN NEW;
    END IF;

    -- Caso 2: Actualización (UPDATE)
    IF TG_OP = 'UPDATE' THEN

        -- Detección de Cambios de Estado (Status changes take precedence if multiple things change)
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            IF NEW.status = 'cancelled' THEN
                v_action := 'cancelled';
                v_details := jsonb_build_object('reason', NEW.cancel_reason);
            ELSIF NEW.status = 'paused' THEN
                v_action := 'paused';
                v_details := jsonb_build_object('pause_until', NEW.pause_until);
            ELSIF NEW.status = 'active' AND OLD.status = 'paused' THEN
                v_action := 'resumed';
            ELSIF NEW.status = 'active' AND OLD.status = 'past_due' THEN
                v_action := 'renewal';
            ELSIF NEW.status = 'active' AND OLD.status = 'cancelled' THEN
                v_action := 'reactivated';
            ELSIF NEW.status = 'past_due' THEN
                v_action := 'payment_failed'; 
                v_details := jsonb_build_object('reason', 'payment_declined_or_past_due');
            END IF;

        -- Detección de Cambios de Configuración
        ELSIF OLD.frequency_days IS DISTINCT FROM NEW.frequency_days THEN
            v_action := 'frequency_changed';
            v_details := jsonb_build_object('old_frequency', OLD.frequency_days, 'new_frequency', NEW.frequency_days);

        ELSIF OLD.product_id IS DISTINCT FROM NEW.product_id OR OLD.variant_sku IS DISTINCT FROM NEW.variant_sku THEN
            v_action := 'product_changed';
            v_details := jsonb_build_object(
                'old_product', OLD.product_id, 
                'new_product', NEW.product_id,
                'old_variant', OLD.variant_sku,
                'new_variant', NEW.variant_sku
            );

        ELSIF OLD.shipping_address_id IS DISTINCT FROM NEW.shipping_address_id THEN
            v_action := 'address_changed';
            v_details := jsonb_build_object('old_address', OLD.shipping_address_id, 'new_address', NEW.shipping_address_id);

        ELSIF (OLD.payment_token_id IS DISTINCT FROM NEW.payment_token_id) OR (OLD.billing_profile_id IS DISTINCT FROM NEW.billing_profile_id) THEN
            v_action := 'payment_changed';
            v_details := jsonb_build_object(
                'old_payment_token', OLD.payment_token_id, 
                'new_payment_token', NEW.payment_token_id,
                'old_billing_profile', OLD.billing_profile_id,
                'new_billing_profile', NEW.billing_profile_id
            );

        -- Detección de Renovación
        ELSIF OLD.next_billing_date IS DISTINCT FROM NEW.next_billing_date AND NEW.status = 'active' AND OLD.status = 'active' THEN
             v_action := 'renewal';
             v_details := jsonb_build_object('next_billing_date', NEW.next_billing_date);
        END IF;

        -- Si detectamos una acción válida, insertamos al historial
        IF v_action IS NOT NULL THEN
            INSERT INTO subscription_history (subscription_id, action, details)
            VALUES (NEW.id, v_action, v_details);
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Adjuntar el trigger a la tabla subscriptions
DROP TRIGGER IF EXISTS trg_log_subscription_history ON subscriptions;
CREATE TRIGGER trg_log_subscription_history
AFTER INSERT OR UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION log_subscription_history();