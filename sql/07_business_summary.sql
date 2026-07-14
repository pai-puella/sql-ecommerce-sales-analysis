-- ============================================================
-- 07_business_summary.sql
-- Итоговая сводка ключевых метрик проекта.
-- Все метрики: order_status = 'delivered', выручка = order_items.price,
-- клиент = customer_unique_id.
-- ============================================================

WITH delivered AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM raw.orders o
    JOIN raw.customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

order_revenue AS (
    SELECT order_id, SUM(price) AS revenue
    FROM raw.order_items
    GROUP BY order_id
),

order_review AS (
    SELECT order_id, AVG(review_score::numeric) AS review_score
    FROM raw.order_reviews
    GROUP BY order_id
),

customer_freq AS (
    SELECT customer_unique_id, COUNT(*) AS orders_count
    FROM delivered
    GROUP BY customer_unique_id
)

SELECT
    -- Выручка
    ROUND(SUM(r.revenue), 2)                                          AS total_revenue,
    -- Заказы
    COUNT(DISTINCT d.order_id)                                        AS delivered_orders,
    -- Уникальные клиенты
    COUNT(DISTINCT d.customer_unique_id)                              AS unique_customers,
    -- Средний чек
    ROUND(SUM(r.revenue) / NULLIF(COUNT(DISTINCT d.order_id), 0), 2)  AS avg_order_value,
    -- Доля повторных покупателей
    ROUND(100.0 * (SELECT COUNT(*) FROM customer_freq WHERE orders_count >= 2)
          / NULLIF((SELECT COUNT(*) FROM customer_freq), 0), 2)       AS repeat_purchase_rate_pct,
    -- Доля опозданий
    ROUND(100.0 * COUNT(*) FILTER (
              WHERE d.order_delivered_customer_date > d.order_estimated_delivery_date)
          / NULLIF(COUNT(*) FILTER (
              WHERE d.order_delivered_customer_date IS NOT NULL
                AND d.order_estimated_delivery_date IS NOT NULL), 0), 2) AS late_delivery_rate_pct,
    -- Средняя оценка
    ROUND(AVG(rev.review_score), 3)                                   AS avg_review_score
FROM delivered d
JOIN order_revenue r   ON d.order_id = r.order_id
LEFT JOIN order_review rev ON d.order_id = rev.order_id;