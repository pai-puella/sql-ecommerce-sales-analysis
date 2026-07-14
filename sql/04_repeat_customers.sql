-- ============================================================
-- 04_repeat_customers.sql
-- Анализ повторных покупок.
-- Покупатель идентифицируется по customer_unique_id (не customer_id).
-- Учитываем только доставленные заказы.
-- ============================================================

WITH customer_orders AS (
    -- Один ряд на доставленный заказ, с привязкой к реальному покупателю
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM raw.orders o
    JOIN raw.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

orders_per_customer AS (
    -- Сколько доставленных заказов у каждого покупателя
    SELECT
        customer_unique_id,
        COUNT(*) AS orders_count
    FROM customer_orders
    GROUP BY customer_unique_id
)

-- ------------------------------------------------------------
-- 1. Ключевые метрики повторных покупок
-- ------------------------------------------------------------
SELECT
    COUNT(*)                                                      AS total_customers,
    COUNT(*) FILTER (WHERE orders_count >= 2)                     AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE orders_count >= 2)
          / NULLIF(COUNT(*), 0), 2)                              AS repeat_rate_pct,
    ROUND(AVG(orders_count), 3)                                  AS avg_orders_per_customer,
    MAX(orders_count)                                            AS max_orders_single_customer
FROM orders_per_customer;

-- ------------------------------------------------------------
-- 2. Распределение покупателей по числу заказов
-- ------------------------------------------------------------
WITH customer_orders AS (
    SELECT c.customer_unique_id, o.order_id
    FROM raw.orders o
    JOIN raw.customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
orders_per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders_count
    FROM customer_orders
    GROUP BY customer_unique_id
)
SELECT
    orders_count,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders_per_customer
GROUP BY orders_count
ORDER BY orders_count;