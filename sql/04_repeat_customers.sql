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

-- ------------------------------------------------------------
-- 3. Дни между первой и второй покупкой (для повторных клиентов)
-- Используем ROW_NUMBER для нумерации заказов и LAG для интервала.
-- ------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS order_seq
    FROM raw.orders o
    JOIN raw.customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_two AS (
    -- Берём только первые две покупки каждого клиента
    SELECT
        customer_unique_id,
        order_purchase_timestamp,
        order_seq,
        LAG(order_purchase_timestamp) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS prev_purchase
    FROM customer_orders
    WHERE order_seq <= 2
)
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (order_purchase_timestamp - prev_purchase)) / 86400.0), 1) AS avg_days_between,
    ROUND(MIN(EXTRACT(EPOCH FROM (order_purchase_timestamp - prev_purchase)) / 86400.0), 1) AS min_days,
    ROUND(MAX(EXTRACT(EPOCH FROM (order_purchase_timestamp - prev_purchase)) / 86400.0), 1) AS max_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (order_purchase_timestamp - prev_purchase)) / 86400.0
    ) AS median_days
FROM first_two
WHERE order_seq = 2;

-- ------------------------------------------------------------
-- 4. Top-10 покупателей по суммарной выручке
-- ------------------------------------------------------------
WITH customer_revenue AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_count,
        SUM(oi.price)              AS total_revenue
    FROM raw.orders o
    JOIN raw.customers c   ON o.customer_id = c.customer_id
    JOIN raw.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    orders_count,
    ROUND(total_revenue, 2) AS total_revenue
FROM customer_revenue
ORDER BY total_revenue DESC
LIMIT 10;