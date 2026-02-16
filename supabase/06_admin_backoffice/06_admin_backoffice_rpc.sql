-- Content from admin_rpc.sql
-- ============================================================================
-- MasKot | Admin Module (admin_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Obtener métricas del dashboard
CREATE OR REPLACE FUNCTION get_dashboard_metrics(
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_date_from TIMESTAMPTZ := COALESCE(p_date_from, NOW() - INTERVAL '30 days');
    v_date_to TIMESTAMPTZ := COALESCE(p_date_to, NOW());
    v_total_sales NUMERIC;
    v_pending_orders INTEGER;
    v_active_subs INTEGER;
    v_mrr NUMERIC;
BEGIN
    -- Ventas totales
    SELECT COALESCE(SUM(total), 0) INTO v_total_sales
    FROM orders 
    WHERE created_at BETWEEN v_date_from AND v_date_to
      AND payment_status = 'paid';
    
    -- Órdenes pendientes
    SELECT COUNT(*) INTO v_pending_orders
    FROM orders WHERE status = 'pending';
    
    -- Suscripciones activas
    SELECT COUNT(*) INTO v_active_subs
    FROM subscriptions WHERE status = 'active';
    
    -- MRR (calculado de suscripciones)
    SELECT COALESCE(SUM(p.price * s.quantity), 0) INTO v_mrr
    FROM subscriptions s
    JOIN products p ON p.id = s.product_id
    WHERE s.status = 'active';
    
    RETURN jsonb_build_object(
        'total_sales', ROUND(v_total_sales, 2),
        'pending_orders', v_pending_orders,
        'active_subscriptions', v_active_subs,
        'mrr', ROUND(v_mrr, 2),
        'low_stock_products', (
            SELECT jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'stock', p.stock_quantity))
            FROM products p
            JOIN stock_alerts sa ON sa.product_id = p.id
            WHERE p.stock_quantity <= sa.threshold AND sa.is_active = TRUE
        ),
        'top_products', (
            SELECT jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'total_sold', COALESCE(SUM(oi.quantity), 0)))
            FROM products p
            LEFT JOIN order_items oi ON oi.product_id = p.id
            LEFT JOIN orders o ON o.id = oi.order_id AND o.created_at BETWEEN v_date_from AND v_date_to
            GROUP BY p.id, p.name
            ORDER BY SUM(oi.quantity) DESC NULLS LAST
            LIMIT 5
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Obtener evolución de ventas para gráfico
CREATE OR REPLACE FUNCTION get_sales_evolution(
    p_date_from TIMESTAMPTZ,
    p_date_to TIMESTAMPTZ,
    p_granularity TEXT DEFAULT 'day'
) RETURNS JSONB AS $$
DECLARE
    v_interval INTERVAL;
    v_format TEXT;
BEGIN
    -- Determinar intervalo y formato según granularidad
    v_interval := CASE p_granularity
        WHEN 'hour' THEN INTERVAL '1 hour'
        WHEN 'day' THEN INTERVAL '1 day'
        WHEN 'week' THEN INTERVAL '1 week'
        WHEN 'month' THEN INTERVAL '1 month'
        ELSE INTERVAL '1 day'
    END;
    
    v_format := CASE p_granularity
        WHEN 'hour' THEN 'YYYY-MM-DD HH24:00'
        WHEN 'day' THEN 'YYYY-MM-DD'
        WHEN 'week' THEN 'IYYY-IW'
        WHEN 'month' THEN 'YYYY-MM'
        ELSE 'YYYY-MM-DD'
    END;
    
    RETURN (
        SELECT jsonb_agg(jsonb_build_object(
            'date', TO_CHAR(date_trunc(p_granularity, created_at), v_format),
            'total_sales', SUM(total),
            'order_count', COUNT(*)
        ))
        FROM orders
        WHERE created_at BETWEEN p_date_from AND p_date_to
          AND payment_status = 'paid'
        GROUP BY date_trunc(p_granularity, created_at)
        ORDER BY date_trunc(p_granularity, created_at)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Ajustar stock manualmente
CREATE OR REPLACE FUNCTION adjust_stock(
    p_product_id BIGINT,
    p_quantity INTEGER,
    p_type inventory_movement_type,
    p_reason TEXT,
    p_reference_id TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_new_stock INTEGER;
    v_movement_id BIGINT;
BEGIN
    -- Registrar movimiento
    INSERT INTO inventory_movements (product_id, type, quantity, reason, reference_id, created_by)
    VALUES (p_product_id, p_type, p_quantity, p_reason, p_reference_id, auth.uid())
    RETURNING id INTO v_movement_id;
    
    -- Actualizar stock
    UPDATE products 
    SET stock_quantity = stock_quantity + p_quantity, updated_at = NOW()
    WHERE id = p_product_id
    RETURNING stock_quantity INTO v_new_stock;
    
    RETURN jsonb_build_object('success', true, 'new_stock', v_new_stock, 'movement_id', v_movement_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Verificar umbral de stock bajo
CREATE OR REPLACE FUNCTION handle_stock_alert_check()
RETURNS TRIGGER AS $$
DECLARE
    v_alert RECORD;
BEGIN
    -- Buscar alerta activa para este producto
    SELECT * INTO v_alert FROM stock_alerts
    WHERE product_id = NEW.id AND is_active = TRUE;
    
    IF v_alert IS NOT NULL AND NEW.stock_quantity <= v_alert.threshold THEN
        -- TODO: Integrar con sistema de notificaciones
        -- Aquí se dispararía una notificación por email
        NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_product_stock_update
AFTER UPDATE OF stock_quantity ON products
FOR EACH ROW EXECUTE FUNCTION handle_stock_alert_check();



