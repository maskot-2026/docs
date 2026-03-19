-- ============================================================================
-- MIGRATION: subscriptions FK constraints → SET NULL (nullable)
-- Ejecutar ANTES de actualizar las RPC si se migra desde RESTRICT.
-- Permite eliminar tarjetas/direcciones/perfiles cuando la suscripción está
-- cancelada, preservando el registro histórico con FKs nulas.
-- ============================================================================
-- ALTER TABLE subscriptions
--     ALTER COLUMN shipping_address_id DROP NOT NULL,
--     ALTER COLUMN billing_profile_id  DROP NOT NULL,
--     ALTER COLUMN payment_token_id    DROP NOT NULL;
--
-- ALTER TABLE subscriptions
--     DROP CONSTRAINT subscriptions_shipping_address_id_fkey,
--     DROP CONSTRAINT subscriptions_billing_profile_id_fkey,
--     DROP CONSTRAINT subscriptions_payment_token_id_fkey;
--
-- ALTER TABLE subscriptions
--     ADD CONSTRAINT subscriptions_shipping_address_id_fkey
--         FOREIGN KEY (shipping_address_id) REFERENCES shipping_addresses(id) ON DELETE SET NULL,
--     ADD CONSTRAINT subscriptions_billing_profile_id_fkey
--         FOREIGN KEY (billing_profile_id) REFERENCES billing_profiles(id) ON DELETE SET NULL,
--     ADD CONSTRAINT subscriptions_payment_token_id_fkey
--         FOREIGN KEY (payment_token_id) REFERENCES payment_tokens(id) ON DELETE SET NULL;
-- ============================================================================

CREATE OR REPLACE FUNCTION create_order(
    p_cart_id BIGINT,
    p_shipping_address JSONB,          -- Inline snapshot: {recipient_name, phone, address_line1, address_line2, district, department}
    p_billing_profile JSONB,           -- Inline snapshot: {document_type, document_number, customer_name, fiscal_address}
    p_contact_email TEXT,
    p_checkout_id TEXT DEFAULT NULL,
    p_cart_session_id TEXT DEFAULT NULL      -- Cart session ID del guest para poder limpiar su carrito post-pago
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
    v_auth_uid UUID := auth.uid();
    v_profile_id BIGINT := NULL;
BEGIN
    -- 1. Obtener perfil de usuario si está autenticado
    IF v_auth_uid IS NOT NULL THEN
        SELECT id INTO v_profile_id FROM profiles WHERE user_id = v_auth_uid AND deleted_at IS NULL;
        IF v_profile_id IS NULL THEN
            RAISE EXCEPTION 'Perfil no autorizado o no encontrado';
        END IF;
    END IF;

    -- 2. Validar Carrito
    IF v_profile_id IS NOT NULL THEN
        SELECT * INTO v_cart FROM carts WHERE id = p_cart_id AND profile_id = v_profile_id;
    ELSE
        SELECT * INTO v_cart FROM carts WHERE id = p_cart_id AND profile_id IS NULL;
    END IF;

    IF NOT FOUND OR jsonb_array_length(v_cart.items) = 0 THEN
        RAISE EXCEPTION 'El carrito está vacío o no es válido';
    END IF;

    -- 2.5 Validación de Seguridad: Un invitado no puede comprar suscripciones
    IF v_profile_id IS NULL THEN
        IF EXISTS (
            SELECT 1 FROM jsonb_array_elements(v_cart.items) AS item
            WHERE COALESCE((item->>'is_subscription')::BOOLEAN, FALSE) = TRUE
              AND COALESCE((item->>'selected')::BOOLEAN, TRUE) = TRUE
        ) THEN
            RAISE EXCEPTION 'Debes iniciar sesión para comprar suscripciones';
        END IF;
    END IF;

    -- 3. Validar datos de envío y email
    IF p_shipping_address IS NULL OR p_shipping_address->>'district' IS NULL THEN
        RAISE EXCEPTION 'Dirección de envío incompleta';
    END IF;

    IF p_contact_email IS NULL OR p_contact_email = '' THEN
        RAISE EXCEPTION 'Email de contacto es requerido';
    END IF;

    -- 4. Calcular totales usando calculate_cart_totals (single source of truth)
    v_district := p_shipping_address->>'district';
    v_totals := calculate_cart_totals(p_cart_id, v_district, NULL);

    v_subtotal := (v_totals->>'subtotal')::NUMERIC;
    v_discount := (v_totals->>'discount')::NUMERIC;
    v_shipping_cost := (v_totals->>'shipping_cost')::NUMERIC;
    v_total := (v_totals->>'total')::NUMERIC;

    -- 5. Validar stock ANTES de tocar cupón u orden (fail-fast)
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart.items)
    LOOP
        IF COALESCE((v_item->>'selected')::BOOLEAN, TRUE) = TRUE THEN
            DECLARE
                v_current_stock INTEGER;
                v_requested_qty INTEGER := (v_item->>'quantity')::INTEGER;
                v_product_name TEXT := v_item->>'name';
                v_sku TEXT := v_item->>'variant_sku';
            BEGIN
                SELECT (v->>'stock')::INTEGER INTO v_current_stock
                FROM products p, jsonb_array_elements(p.variants) AS v
                WHERE p.id = (v_item->>'product_id')::BIGINT
                  AND v->>'sku' = v_sku;

                IF v_current_stock IS NULL THEN
                    RAISE EXCEPTION 'Producto "%" (SKU: %) no encontrado o sin variante válida', v_product_name, v_sku;
                END IF;

                IF v_current_stock < v_requested_qty THEN
                    IF v_current_stock = 0 THEN
                        RAISE EXCEPTION '"%" se agotó. Ya no hay stock disponible.', v_product_name;
                    ELSE
                        RAISE EXCEPTION 'Stock insuficiente para "%". Solicitaste % pero solo quedan % unidades.', v_product_name, v_requested_qty, v_current_stock;
                    END IF;
                END IF;
            END;
        END IF;
    END LOOP;

    -- 6. Incrementar cupón SOLO después de validar stock (evita incrementar si falla)
    IF v_cart.coupon_id IS NOT NULL AND v_totals->>'applied_coupon' IS NOT NULL THEN
        UPDATE coupons SET used_count = used_count + 1 WHERE id = v_cart.coupon_id;
    END IF;

    -- 7. Crear la orden central
    INSERT INTO orders (
        profile_id, cart_session_id, status, subtotal, discount, shipping_cost, total,
        shipping_address, billing_profile, payment_status, contact_email, checkout_id
    ) VALUES (
        v_profile_id, p_cart_session_id, 'pending', v_subtotal, v_discount, v_shipping_cost, v_total,
        p_shipping_address, COALESCE(p_billing_profile, '{}'::jsonb),
        'pending', p_contact_email, p_checkout_id
    ) RETURNING id INTO v_order_id;

    -- 8. Insertar items + reservar stock (un solo loop, ya validado arriba)
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart.items)
    LOOP
        IF COALESCE((v_item->>'selected')::BOOLEAN, TRUE) = TRUE THEN
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
            
            -- Decrementar stock (seguro porque ya validamos en paso 5)
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
        END IF;
    END LOOP;

    -- 8. NO limpiar carrito aquí. Se limpia SOLO después de confirmar el pago
    -- vía clear_cart_after_payment(). Esto permite reintentar el pago si falla.
    -- El carrito se preserva intacto hasta que el pago sea 'approved'.

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'total', v_total,
        'profile_id', v_profile_id
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
        RAISE EXCEPTION 'Suscripción no encontrada';
    END IF;

    -- Si el estado es el mismo, no hacer nada
    IF v_sub.status = p_new_status THEN
        RAISE EXCEPTION 'La suscripción ya se encuentra en ese estado';
    END IF;

    -- 2. Procesar transición de estado
    IF p_new_status = 'cancelled' THEN
        -- Cancelar (irreversible estructuralmente desde frontend por diseño seguro, pero permitimos reactivar manual)
        UPDATE subscriptions SET status = 'cancelled', cancel_reason = p_cancel_reason, updated_at = NOW() WHERE id = p_subscription_id;

    ELSIF p_new_status = 'paused' THEN
        -- Pausar
        IF v_sub.status != 'active' THEN
            RAISE EXCEPTION 'Solo se pueden pausar suscripciones activas';
        END IF;

        IF p_pause_days IS NULL OR p_pause_days <= 0 OR p_pause_days > 60 THEN
            RAISE EXCEPTION 'Los días de pausa deben estar entre 1 y 60 días';
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
            -- Validar que los FKs nulleados por SET NULL no bloqueen la reactivación
            IF v_sub.payment_token_id IS NULL THEN
                RAISE EXCEPTION 'MISSING_FK:payment_token — La tarjeta asociada fue eliminada. Agrega una nueva tarjeta antes de reactivar.';
            END IF;
            IF v_sub.shipping_address_id IS NULL THEN
                RAISE EXCEPTION 'MISSING_FK:shipping_address — La dirección de envío asociada fue eliminada. Agrega una nueva dirección antes de reactivar.';
            END IF;
            IF v_sub.billing_profile_id IS NULL THEN
                RAISE EXCEPTION 'MISSING_FK:billing_profile — El perfil de facturación asociado fue eliminado. Agrega uno nuevo antes de reactivar.';
            END IF;

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
            RAISE EXCEPTION 'Solo se pueden reanudar suscripciones pausadas, canceladas o vencidas (past_due)';
        END IF;

    ELSE
        RAISE EXCEPTION 'Transición de estado no soportada o prohibida';
    END IF;

    -- NOTA: No insertamos en `subscription_history` porque el trigger `trg_log_subscription_history` 
    -- detectará el UPDATE de la columna `status` y lo hará automáticamente.

    RETURN jsonb_build_object(
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

-- ============================================================================
-- 6. Conversión Automática de Orden a Suscripción post-pago
-- ============================================================================
CREATE OR REPLACE FUNCTION create_subscription_from_order(
    p_order_id BIGINT,
    p_payment_token_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    v_order RECORD;
    v_item RECORD;
    v_shipping_address_id BIGINT;
    v_billing_profile_id BIGINT;
    v_subs_created INTEGER := 0;
BEGIN
    -- 1. Buscar la orden y validar requisitos
    SELECT * INTO v_order FROM orders WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada';
    END IF;

    IF v_order.profile_id IS NULL THEN
        RAISE EXCEPTION 'Solo usuarios autenticados pueden tener suscripciones';
    END IF;

    -- Validar que el token pertenezca al usuario (omitiendo RLS por ahora, es backend to backend)
    IF NOT EXISTS (SELECT 1 FROM payment_tokens WHERE id = p_payment_token_id AND profile_id = v_order.profile_id) THEN
        RAISE EXCEPTION 'Token de pago inválido o no pertenece al usuario';
    END IF;

    -- Validar que los snapshots tengan label (requerido para el upsert ON CONFLICT (profile_id, label))
    IF COALESCE(v_order.shipping_address->>'label', '') = '' THEN
        RAISE EXCEPTION 'shipping_address no tiene label en la orden %', p_order_id;
    END IF;
    IF COALESCE(v_order.billing_profile->>'label', '') = '' THEN
        RAISE EXCEPTION 'billing_profile no tiene label en la orden %', p_order_id;
    END IF;

    -- 2. Resolver Shipping Address — upsert por (profile_id, label), actualizando datos si ya existe.
    -- DO UPDATE garantiza que RETURNING siempre retorna el id (insert o update),
    -- eliminando la necesidad del SELECT de fallback.
    INSERT INTO shipping_addresses (
        profile_id, label, recipient_name, phone, address_line1, address_line2, district, department, postal_code, is_default
    ) VALUES (
        v_order.profile_id,
        v_order.shipping_address->>'label',
        v_order.shipping_address->>'recipient_name',
        v_order.shipping_address->>'phone',
        v_order.shipping_address->>'address_line1',
        v_order.shipping_address->>'address_line2',
        v_order.shipping_address->>'district',
        v_order.shipping_address->>'department',
        v_order.shipping_address->>'postal_code',
        FALSE
    )
    ON CONFLICT (profile_id, label) DO UPDATE SET
        recipient_name = EXCLUDED.recipient_name,
        phone          = EXCLUDED.phone,
        address_line1  = EXCLUDED.address_line1,
        address_line2  = EXCLUDED.address_line2,
        district       = EXCLUDED.district,
        department     = EXCLUDED.department,
        postal_code    = EXCLUDED.postal_code
    RETURNING id INTO v_shipping_address_id;

    -- 3. Resolver Billing Profile — upsert por (profile_id, label), actualizando datos si ya existe.
    INSERT INTO billing_profiles (
        profile_id, label, doc_type, doc_number, legal_name, legal_address, is_default
    ) VALUES (
        v_order.profile_id,
        v_order.billing_profile->>'label',
        (v_order.billing_profile->>'doc_type')::document_type,
        v_order.billing_profile->>'doc_number',
        v_order.billing_profile->>'legal_name',
        v_order.billing_profile->>'legal_address',
        FALSE
    )
    ON CONFLICT (profile_id, label) DO UPDATE SET
        doc_type     = EXCLUDED.doc_type,
        doc_number   = EXCLUDED.doc_number,
        legal_name   = EXCLUDED.legal_name,
        legal_address = EXCLUDED.legal_address
    RETURNING id INTO v_billing_profile_id;

    -- 4. Iterar sobre los Items de la Orden y crear Suscripciones
    FOR v_item IN (SELECT * FROM order_items WHERE order_id = p_order_id AND is_subscription = TRUE)
    LOOP
        INSERT INTO subscriptions (
            profile_id,
            product_id,
            product_name,
            variant_sku,
            variant_attributes,
            variant_price,
            quantity,
            frequency_days,
            status,
            next_billing_date,
            shipping_address_id,
            billing_profile_id,
            payment_token_id
        ) VALUES (
            v_order.profile_id,
            v_item.product_id,
            v_item.product_name,
            v_item.variant_sku,
            v_item.variant_attributes,
            v_item.unit_price, -- Usamos el precio unitario congelado de la orden
            v_item.quantity,
            v_item.subscription_frequency_days,
            'active',
            NOW() + (v_item.subscription_frequency_days || ' days')::INTERVAL,
            v_shipping_address_id,
            v_billing_profile_id,
            p_payment_token_id
        );
        
        v_subs_created := v_subs_created + 1;
    END LOOP;

    RETURN jsonb_build_object('subscriptions_created', v_subs_created);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Limpiar carrito después de confirmar el pago
-- Se llama desde el backend (Integration-API) post-pago.
-- Usa profile_id (auth) o cart_session_id (guest) almacenados en la orden.
-- ============================================================================
CREATE OR REPLACE FUNCTION clear_order_cart(
    p_order_id BIGINT
) RETURNS void AS $$
DECLARE
    v_order RECORD;
    v_cart RECORD;
    v_remaining_items JSONB;
BEGIN
    -- 1. Buscar la orden
    SELECT * INTO v_order FROM orders WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada';
    END IF;

    IF v_order.payment_status != 'approved' AND v_order.payment_status != 'pending' THEN
        RAISE EXCEPTION 'Pago no confirmado';
    END IF;

    -- 2. Buscar el carrito: por profile_id (auth) o cart_session_id (guest)
    IF v_order.profile_id IS NOT NULL THEN
        SELECT * INTO v_cart FROM carts WHERE profile_id = v_order.profile_id;
    ELSIF v_order.cart_session_id IS NOT NULL THEN
        SELECT * INTO v_cart FROM carts WHERE session_id = v_order.cart_session_id;
    ELSE
        RAISE EXCEPTION 'No hay profile_id ni cart_session_id en la orden';
    END IF;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- 3. Calcular items restantes (no seleccionados) y actualizar el carrito
    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb)
    INTO v_remaining_items
    FROM jsonb_array_elements(v_cart.items) AS item
    WHERE COALESCE((item->>'selected')::BOOLEAN, TRUE) = FALSE;

    UPDATE carts
    SET items = v_remaining_items,
        coupon_id = NULL,
        updated_at = NOW()
    WHERE id = v_cart.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Restaurar stock y revertir cupón de una orden
-- Solo maneja inventario, NO toca el estado de la orden (eso lo hace el servicio).
-- ============================================================================
CREATE OR REPLACE FUNCTION restore_order_stock(
    p_order_id BIGINT
) RETURNS void AS $$
DECLARE
    v_order RECORD;
    v_item RECORD;
BEGIN
    SELECT * INTO v_order FROM orders WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada';
    END IF;

    -- Restaurar stock de cada item
    FOR v_item IN 
        SELECT product_id, variant_sku, quantity 
        FROM order_items 
        WHERE order_id = p_order_id
    LOOP
        UPDATE products 
        SET variants = (
            SELECT jsonb_agg(
                CASE 
                    WHEN v->>'sku' = v_item.variant_sku THEN 
                        jsonb_set(v, '{stock}', ((v->>'stock')::int + v_item.quantity)::text::jsonb)
                    ELSE v 
                END
            )
            FROM jsonb_array_elements(variants) AS v
        )
        WHERE id = v_item.product_id;
    END LOOP;

    -- Revertir cupón si había
    UPDATE coupons SET used_count = GREATEST(used_count - 1, 0) 
    WHERE id IN (
        SELECT coupon_id FROM carts WHERE profile_id = v_order.profile_id
    ) AND v_order.profile_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Auto-cancelar órdenes pendientes expiradas (sin intento de pago)
-- Safety net via pg_cron para edge cases (crash de servidor, deploy, etc.).
-- IMPORTANTE: Solo cancela órdenes con payment_status='pending' (sin intento de pago).
-- Las órdenes con payment_status='in_process' (pago en revisión antifraude)
-- NO son tocadas aquí; el webhook de MP resolverá su estado final.
-- SELECT cron.schedule('cancel-expired-orders', '*/5 * * * *', $$SELECT cancel_expired_pending_orders()$$);
-- ============================================================================
CREATE OR REPLACE FUNCTION cancel_expired_pending_orders()
RETURNS JSONB AS $$
DECLARE
    v_expired_order RECORD;
    v_cancelled_count INTEGER := 0;
BEGIN
    FOR v_expired_order IN 
        SELECT o.id
        FROM orders o
        WHERE o.payment_status = 'pending'   -- Sin intento de pago (no in_process)
          AND o.status = 'pending'
          AND o.created_at < NOW() - INTERVAL '15 minutes'  -- 15 min: tiempo suficiente para completar el checkout; limpia rápido ordenes huérfanas por crash
    LOOP
        -- Restaurar stock y cupón
        PERFORM restore_order_stock(v_expired_order.id);

        -- Cancelar la orden
        UPDATE orders 
        SET status = 'cancelled', 
            payment_status = 'cancelled',
            updated_at = NOW()
        WHERE id = v_expired_order.id;

        v_cancelled_count := v_cancelled_count + 1;
    END LOOP;

    RETURN jsonb_build_object('cancelled_count', v_cancelled_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Obtener suscripciones vencidas (para renovaciones automáticas)
-- Retorna JSONB para simplificar el consumo desde el cliente Python.
-- Hace JOIN con auth.users para obtener el email del pagador (necesario para MP customer).
-- ============================================================================
CREATE OR REPLACE FUNCTION get_due_subscriptions()
RETURNS JSONB AS $$
BEGIN
    RETURN (
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id',                   s.id,
                    'profile_id',           s.profile_id,
                    'user_email',           u.email,
                    'product_name',         s.product_name,
                    'variant_price',        s.variant_price,
                    'quantity',             s.quantity,
                    'frequency_days',       s.frequency_days,
                    'next_billing_date',    s.next_billing_date,
                    'payment_token_id',     s.payment_token_id,
                    'mp_card_id',           pt.token_id,
                    'customer_id',          pt.customer_id,
                    'card_brand',           pt.card_brand,
                    'shipping_address_id',  s.shipping_address_id,
                    'billing_profile_id',   s.billing_profile_id
                )
            ),
            '[]'::jsonb
        )
        FROM subscriptions s
        JOIN profiles       p  ON p.id  = s.profile_id
        JOIN auth.users     u  ON u.id  = p.user_id
        JOIN payment_tokens pt ON pt.id = s.payment_token_id
        WHERE s.next_billing_date <= NOW()
          AND s.status = 'active'
          AND s.payment_token_id IS NOT NULL    -- red de seguridad: nunca renovar sin token
          AND s.shipping_address_id IS NOT NULL -- red de seguridad: nunca renovar sin dirección
          AND s.billing_profile_id IS NOT NULL  -- red de seguridad: nunca renovar sin perfil de facturación
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;




-- ============================================================================
-- pg_cron: Llamar al endpoint de renovaciones cada hora.
-- Requiere extensión pg_net (habilitada en Supabase por defecto).
-- Reemplaza la URL y el secret con tus valores reales antes de activar.
--
-- SELECT cron.schedule(
--   'process-subscription-renewals',
--   '0 * * * *',
--   $$ SELECT net.http_post(
--        url     := 'https://TU-API.railway.app/api/v1/payments/webhook/cron-renewals',
--        headers := '{"x-cron-secret": "TU_CRON_SECRET"}'::jsonb,
--        body    := '{}'::jsonb
--      ) $$
-- );
-- ============================================================================


-- ============================================================================
-- RPC: Eliminar método de pago guardado con guard de suscripciones activas
-- Valida propiedad del token (via auth.uid()) y bloquea la eliminación si hay
-- suscripciones activas, en pausa o con cobro fallido vinculadas al token.
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_payment_token(p_token_id BIGINT)
RETURNS void AS $$
DECLARE
    v_profile_id BIGINT;
    v_active_subs TEXT[];
BEGIN
    -- 1. Resolver perfil autenticado desde auth.uid()
    SELECT id INTO v_profile_id
    FROM profiles
    WHERE user_id = auth.uid() AND deleted_at IS NULL;

    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Perfil no encontrado o no autorizado';
    END IF;

    -- 2. Validar propiedad del token
    IF NOT EXISTS (
        SELECT 1 FROM payment_tokens
        WHERE id = p_token_id AND profile_id = v_profile_id
    ) THEN
        RAISE EXCEPTION 'Tarjeta no encontrada o no pertenece a tu cuenta';
    END IF;

    -- 3. Guard: bloquear eliminación si hay suscripciones activas/pausadas/con cobro fallido
    SELECT ARRAY_AGG(product_name) INTO v_active_subs
    FROM subscriptions
    WHERE payment_token_id = p_token_id
      AND status IN ('active', 'paused', 'past_due');

    IF v_active_subs IS NOT NULL THEN
        RAISE EXCEPTION 'ACTIVE_SUBSCRIPTIONS:%', array_to_string(v_active_subs, '|');
    END IF;

    -- 4. Eliminar el token
    DELETE FROM payment_tokens WHERE id = p_token_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Eliminar dirección de envío con guard de suscripción
-- Bloquea el borrado si hay suscripciones activas/pausadas/past_due vinculadas.
-- Suscripciones canceladas: al ser nullable ON DELETE SET NULL, quedan con
-- shipping_address_id = NULL y se preservan como historial.
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_shipping_address(p_address_id BIGINT)
RETURNS void AS $$
DECLARE
    v_profile_id BIGINT;
    v_active_subs TEXT[];
BEGIN
    -- 1. Resolver perfil autenticado
    SELECT id INTO v_profile_id
    FROM profiles
    WHERE user_id = auth.uid() AND deleted_at IS NULL;

    IF v_profile_id IS NULL THEN
        RAISE EXCEPTION 'Perfil no encontrado o no autorizado';
    END IF;

    -- 2. Validar propiedad
    IF NOT EXISTS (
        SELECT 1 FROM shipping_addresses
        WHERE id = p_address_id AND profile_id = v_profile_id
    ) THEN
        RAISE EXCEPTION 'Dirección no encontrada o no pertenece a tu cuenta';
    END IF;

    -- 3. Guard: bloquear si hay suscripciones que aún dependen de esta dirección
    SELECT ARRAY_AGG(product_name) INTO v_active_subs
    FROM subscriptions
    WHERE shipping_address_id = p_address_id
      AND status IN ('active', 'paused', 'past_due');

    IF v_active_subs IS NOT NULL THEN
        RAISE EXCEPTION 'ACTIVE_SUBSCRIPTIONS:%', array_to_string(v_active_subs, '|');
    END IF;

    -- 4. Eliminar (las suscripciones canceladas que apuntaban aquí quedan con SET NULL automáticamente)
    DELETE FROM shipping_addresses WHERE id = p_address_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- RPC: Eliminar perfil de facturación con guard de suscripción
-- Misma estrategia que delete_shipping_address y delete_payment_token.
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_billing_profile(p_profile_id BIGINT)
RETURNS void AS $$
DECLARE
    v_owner_profile_id BIGINT;
    v_active_subs TEXT[];
BEGIN
    -- 1. Resolver perfil autenticado
    SELECT id INTO v_owner_profile_id
    FROM profiles
    WHERE user_id = auth.uid() AND deleted_at IS NULL;

    IF v_owner_profile_id IS NULL THEN
        RAISE EXCEPTION 'Perfil no encontrado o no autorizado';
    END IF;

    -- 2. Validar propiedad
    IF NOT EXISTS (
        SELECT 1 FROM billing_profiles
        WHERE id = p_profile_id AND profile_id = v_owner_profile_id
    ) THEN
        RAISE EXCEPTION 'Perfil de facturación no encontrado o no pertenece a tu cuenta';
    END IF;

    -- 3. Guard: bloquear si hay suscripciones activas/pausadas/past_due
    SELECT ARRAY_AGG(product_name) INTO v_active_subs
    FROM subscriptions
    WHERE billing_profile_id = p_profile_id
      AND status IN ('active', 'paused', 'past_due');

    IF v_active_subs IS NOT NULL THEN
        RAISE EXCEPTION 'ACTIVE_SUBSCRIPTIONS:%', array_to_string(v_active_subs, '|');
    END IF;

    -- 4. Eliminar (suscripciones canceladas quedan con billing_profile_id = NULL)
    DELETE FROM billing_profiles WHERE id = p_profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;