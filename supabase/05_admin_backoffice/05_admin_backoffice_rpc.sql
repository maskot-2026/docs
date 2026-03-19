-- Content from admin_rpc.sql
-- ============================================================================
-- MasKot | Admin Module (admin_rpc.sql)
-- RPC Implementations
-- ============================================================================

-- RPC: Obtener resumen de reportes (ventas y suscripciones)
CREATE OR REPLACE FUNCTION get_reports_overview(
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_date_from TIMESTAMPTZ := COALESCE(p_date_from, NOW() - INTERVAL '30 days');
    v_date_to TIMESTAMPTZ := COALESCE(p_date_to, NOW());
    v_total_sales NUMERIC;
    v_approved_orders INTEGER;
    v_avg_order_value NUMERIC;
    v_active_subs INTEGER;
    v_mrr NUMERIC;
BEGIN
    -- Ventas aprobadas y ordenes confirmadas
    SELECT COALESCE(SUM(total), 0), COUNT(*) INTO v_total_sales, v_approved_orders
    FROM orders
    WHERE created_at BETWEEN v_date_from AND v_date_to
      AND payment_status = 'approved';

    v_avg_order_value := CASE
        WHEN v_approved_orders > 0 THEN v_total_sales / v_approved_orders
        ELSE 0
    END;

    -- Suscripciones activas
    SELECT COUNT(*) INTO v_active_subs
    FROM subscriptions WHERE status = 'active';

    -- MRR (estimado con precios de suscripcion)
    SELECT COALESCE(SUM(variant_price * quantity), 0) INTO v_mrr
    FROM subscriptions
    WHERE status = 'active';

    RETURN jsonb_build_object(
        'total_sales', ROUND(v_total_sales, 2),
        'approved_orders', v_approved_orders,
        'avg_order_value', ROUND(v_avg_order_value, 2),
        'active_subscriptions', v_active_subs,
        'mrr', ROUND(v_mrr, 2),
        'top_products', (
            SELECT COALESCE(jsonb_agg(product_row), '[]'::jsonb)
            FROM (
                SELECT
                    oi.product_id AS product_id,
                    oi.product_name AS product_name,
                    COALESCE(SUM(oi.quantity), 0) AS units_sold,
                    COALESCE(SUM(oi.unit_price * oi.quantity), 0) AS revenue
                FROM order_items oi
                JOIN orders o ON o.id = oi.order_id
                WHERE o.created_at BETWEEN v_date_from AND v_date_to
                  AND o.payment_status = 'approved'
                GROUP BY oi.product_id, oi.product_name
                ORDER BY SUM(oi.unit_price * oi.quantity) DESC NULLS LAST
                LIMIT 5
            ) product_row
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
    v_format TEXT;
BEGIN
    -- Determinar formato según granularidad
    v_format := CASE p_granularity
        WHEN 'hour' THEN 'YYYY-MM-DD HH24:00'
        WHEN 'day' THEN 'YYYY-MM-DD'
        WHEN 'week' THEN 'IYYY-IW'
        WHEN 'month' THEN 'YYYY-MM'
        ELSE 'YYYY-MM-DD'
    END;

    RETURN COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
            'date', TO_CHAR(bucket, v_format),
            'total_sales', total_sales,
            'order_count', order_count
        ) ORDER BY bucket)
        FROM (
            SELECT
                date_trunc(p_granularity, created_at) AS bucket,
                SUM(total) AS total_sales,
                COUNT(*) AS order_count
            FROM orders
            WHERE created_at BETWEEN p_date_from AND p_date_to
              AND payment_status = 'approved'
            GROUP BY bucket
        ) series
    ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;




