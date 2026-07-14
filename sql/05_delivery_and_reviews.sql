-- ============================================================
-- 05_delivery_and_reviews.sql
-- Анализ сроков доставки и их связи с оценками.
-- ВАЖНО: связь ≠ причинность. Формулировки только про корреляцию.
-- Только доставленные заказы с заполненными датами.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Сроки доставки и доля опозданий
-- ------------------------------------------------------------
WITH delivery AS (
    SELECT
        order_id,
        -- Фактический срок доставки в днях (от покупки до вручения)
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0 AS delivery_days,
        -- Отклонение от обещанной даты: >0 = опоздание, <0 = раньше срока
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 AS delay_days
    FROM raw.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*)                                                          AS delivered_orders,
    ROUND(AVG(delivery_days)::numeric, 1)                            AS avg_delivery_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)::numeric, 1) AS median_delivery_days,
    COUNT(*) FILTER (WHERE delay_days > 0)                           AS late_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delay_days > 0) / COUNT(*), 2) AS late_rate_pct,
    ROUND(AVG(delay_days)::numeric, 1)                              AS avg_delay_days
FROM delivery;

-- ------------------------------------------------------------
-- 2. Средний review_score по группам доставки
-- ------------------------------------------------------------
WITH order_delivery AS (
    SELECT
        order_id,
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 AS delay_days
    FROM raw.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
order_review AS (
    -- Один средний балл на заказ (защита от дублей отзывов)
    SELECT order_id, AVG(review_score::numeric) AS review_score
    FROM raw.order_reviews
    GROUP BY order_id
),
joined AS (
    SELECT
        CASE
            WHEN d.delay_days < 0 THEN 'early'
            WHEN d.delay_days = 0 THEN 'on_time'
            ELSE 'late'
        END AS delivery_group,
        r.review_score
    FROM order_delivery d
    JOIN order_review r ON d.order_id = r.order_id
)
SELECT
    delivery_group,
    COUNT(*)                                  AS orders,
    ROUND(AVG(review_score), 3)               AS avg_review_score,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM joined
GROUP BY delivery_group
ORDER BY avg_review_score DESC;

-- ------------------------------------------------------------
-- 3. Распределение оценок 1-5 по группам доставки
-- ------------------------------------------------------------
WITH order_delivery AS (
    SELECT
        order_id,
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 AS delay_days
    FROM raw.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
order_review AS (
    SELECT order_id, ROUND(AVG(review_score::numeric)) AS review_score
    FROM raw.order_reviews
    GROUP BY order_id
),
joined AS (
    SELECT
        CASE WHEN d.delay_days > 0 THEN 'late' ELSE 'on_time_or_early' END AS delivery_group,
        r.review_score
    FROM order_delivery d
    JOIN order_review r ON d.order_id = r.order_id
)
SELECT
    review_score,
    COUNT(*) FILTER (WHERE delivery_group = 'on_time_or_early') AS on_time_or_early,
    COUNT(*) FILTER (WHERE delivery_group = 'late')            AS late
FROM joined
GROUP BY review_score
ORDER BY review_score;