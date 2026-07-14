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