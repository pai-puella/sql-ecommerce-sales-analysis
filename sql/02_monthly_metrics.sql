-- ============================================================
-- 02_monthly_metrics.sql
-- Ежемесячные метрики по доставленным заказам.
-- Выручка = SUM(order_items.price) (без доставки).
-- Только order_status = 'delivered'.
-- ============================================================

WITH delivered_orders AS (
    -- Берём только доставленные заказы и обрезаем дату до месяца
    SELECT
        o.order_id,
        o.customer_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM raw.orders o
    WHERE o.order_status = 'delivered'
),

order_revenue AS (
    -- Считаем по каждому заказу: товарную выручку, доставку, число позиций
    SELECT
        oi.order_id,
        SUM(oi.price)         AS order_item_revenue,
        SUM(oi.freight_value) AS order_freight,
        COUNT(*)              AS items_count
    FROM raw.order_items oi
    GROUP BY oi.order_id
),

monthly AS (
    -- Агрегируем по месяцам
    SELECT
        d.order_month,
        COUNT(DISTINCT d.order_id)      AS orders_count,
        COUNT(DISTINCT d.customer_id)   AS customers_count,
        SUM(r.order_item_revenue)       AS revenue,
        SUM(r.items_count)              AS total_items,
        SUM(r.order_freight)            AS total_freight
    FROM delivered_orders d
    JOIN order_revenue r ON d.order_id = r.order_id
    GROUP BY d.order_month
)

SELECT
    order_month,
    orders_count,
    customers_count,
    ROUND(revenue, 2)                                              AS revenue,
    -- Средний чек = выручка / число заказов
    ROUND(revenue / NULLIF(orders_count, 0), 2)                   AS avg_order_value,
    -- Среднее число позиций в заказе
    ROUND(total_items::numeric / NULLIF(orders_count, 0), 2)      AS avg_items_per_order,
    -- Средняя стоимость доставки на заказ
    ROUND(total_freight / NULLIF(orders_count, 0), 2)             AS avg_freight_per_order,
    -- MoM-изменение выручки, %
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2
    )                                                             AS revenue_mom_pct,
    -- MoM-изменение числа заказов, %
    ROUND(
        100.0 * (orders_count - LAG(orders_count) OVER (ORDER BY order_month))
        / NULLIF(LAG(orders_count) OVER (ORDER BY order_month), 0), 2
    )                                                             AS orders_mom_pct
FROM monthly
ORDER BY order_month;