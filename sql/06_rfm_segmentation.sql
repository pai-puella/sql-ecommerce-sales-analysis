-- ============================================================
-- 06_rfm_segmentation.sql
-- RFM-сегментация клиентов (customer_unique_id).
-- Reference date = MAX(order_purchase_timestamp) в данных.
-- Только delivered-заказы. Выручка = order_items.price.
-- ============================================================

WITH params AS (
    -- Опорная дата: последний день в данных
    SELECT MAX(order_purchase_timestamp) AS ref_date
    FROM raw.orders
    WHERE order_status = 'delivered'
),

customer_orders AS (
    -- Заказы с привязкой к реальному клиенту и товарной выручкой
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        oi.price
    FROM raw.orders o
    JOIN raw.customers c   ON o.customer_id = c.customer_id
    JOIN raw.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),

rfm_base AS (
    -- Базовые R, F, M по каждому клиенту
    SELECT
        co.customer_unique_id,
        EXTRACT(DAY FROM (p.ref_date - MAX(co.order_purchase_timestamp)))::int AS recency_days,
        COUNT(DISTINCT co.order_id)                                            AS frequency,
        ROUND(SUM(co.price), 2)                                                AS monetary
    FROM customer_orders co
    CROSS JOIN params p
    GROUP BY co.customer_unique_id, p.ref_date
),

rfm_scored AS (
    -- Квинтили 1..5. Для recency меньший day = выше балл (DESC).
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_base
),

rfm_segments AS (
    SELECT
        *,
        -- Сегментация на основе R и M (F малоинформативна в этом датасете)
        CASE
            WHEN r_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND m_score <  3 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND m_score >= 3 THEN 'At Risk'
            ELSE 'Hibernating'
        END AS segment
    FROM rfm_scored
)

SELECT
    segment,
    COUNT(*)                                              AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)   AS pct_customers,
    ROUND(AVG(monetary), 2)                              AS avg_revenue_per_customer,
    ROUND(AVG(frequency), 2)                             AS avg_orders,
    ROUND(AVG(recency_days), 0)                          AS avg_recency_days,
    ROUND(SUM(monetary), 2)                              AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;