-- ============================================================
-- 03_category_revenue.sql
-- Анализ выручки по товарным категориям.
-- Выручка = SUM(order_items.price), только delivered-заказы.
-- Названия категорий переведены на английский.
-- ============================================================

WITH delivered_items AS (
    -- Позиции только из доставленных заказов, с категорией товара
    SELECT
        oi.order_id,
        o.customer_id,
        oi.price,
        oi.freight_value,
        COALESCE(t.product_category_name_english,
                 p.product_category_name,
                 'unknown') AS category
    FROM raw.order_items oi
    JOIN raw.orders o
        ON oi.order_id = o.order_id
        AND o.order_status = 'delivered'
    LEFT JOIN raw.products p
        ON oi.product_id = p.product_id
    LEFT JOIN raw.product_category_translation t
        ON p.product_category_name = t.product_category_name
),

category_stats AS (
    SELECT
        category,
        SUM(price)                     AS revenue,
        COUNT(DISTINCT order_id)       AS orders_count,
        COUNT(DISTINCT customer_id)    AS customers_count,
        COUNT(*)                       AS items_count,
        AVG(price)                     AS avg_item_price,
        AVG(freight_value)             AS avg_freight
    FROM delivered_items
    GROUP BY category
)

SELECT
    category,
    ROUND(revenue, 2)                                          AS revenue,
    orders_count,
    customers_count,
    -- Средний чек по категории = выручка / число заказов
    ROUND(revenue / NULLIF(orders_count, 0), 2)               AS avg_order_value,
    ROUND(avg_item_price, 2)                                   AS avg_item_price,
    ROUND(avg_freight, 2)                                      AS avg_freight,
    -- Доля категории в общей выручке, %
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)          AS revenue_share_pct,
    -- Ранг по выручке
    DENSE_RANK() OVER (ORDER BY revenue DESC)                 AS revenue_rank
FROM category_stats
ORDER BY revenue DESC;