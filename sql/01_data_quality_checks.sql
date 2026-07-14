-- ============================================================
-- 01_data_quality_checks.sql
-- Проверка качества и целостности данных перед анализом.
-- Каждый блок: проверка -> результат -> интерпретация в комментарии.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Количество строк в каждой таблице
-- ------------------------------------------------------------
SELECT 'customers'      AS table_name, COUNT(*) AS row_count FROM raw.customers
UNION ALL SELECT 'orders',         COUNT(*) FROM raw.orders
UNION ALL SELECT 'products',       COUNT(*) FROM raw.products
UNION ALL SELECT 'order_items',    COUNT(*) FROM raw.order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM raw.order_payments
UNION ALL SELECT 'order_reviews',  COUNT(*) FROM raw.order_reviews
ORDER BY table_name;

-- ------------------------------------------------------------
-- 2. Дубликаты по ключевым идентификаторам
-- ------------------------------------------------------------

-- 2a. Дубли order_id в orders (ожидаем 0)
SELECT order_id, COUNT(*) AS cnt
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 2b. Дубли customer_id в customers (ожидаем 0)
SELECT customer_id, COUNT(*) AS cnt
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 2c. Дубли review_id в order_reviews (ожидаем > 0 — известная особенность датасета)
SELECT COUNT(*) AS total_reviews,
       COUNT(DISTINCT review_id) AS distinct_review_ids,
       COUNT(*) - COUNT(DISTINCT review_id) AS duplicate_review_ids
FROM raw.order_reviews;

-- ------------------------------------------------------------
-- 3. Пропуски в критичных полях
-- ------------------------------------------------------------

-- 3a. Orders: даты и статус
SELECT
    COUNT(*) FILTER (WHERE order_status IS NULL)                  AS null_status,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL)      AS null_purchase,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)             AS null_approved,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_delivered
FROM raw.orders;

-- 3b. Products: категория
SELECT COUNT(*) AS products_without_category
FROM raw.products
WHERE product_category_name IS NULL;

-- ------------------------------------------------------------
-- 4. Распределение order_status
-- ------------------------------------------------------------
SELECT order_status,
       COUNT(*) AS cnt,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM raw.orders
GROUP BY order_status
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 5. Заказы без позиций (order_items)
-- ------------------------------------------------------------
SELECT COUNT(*) AS orders_without_items
FROM raw.orders o
LEFT JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- ------------------------------------------------------------
-- 6. Заказы без платежей (order_payments)
-- ------------------------------------------------------------
SELECT COUNT(*) AS orders_without_payments
FROM raw.orders o
LEFT JOIN raw.order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- ------------------------------------------------------------
-- 7. Корректность дат: доставка не раньше покупки
-- ------------------------------------------------------------
SELECT COUNT(*) AS delivered_before_purchase
FROM raw.orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- ------------------------------------------------------------
-- 8. Отрицательные или нулевые денежные значения
-- ------------------------------------------------------------

-- 8a. order_items
SELECT
    COUNT(*) FILTER (WHERE price <= 0)         AS non_positive_price,
    COUNT(*) FILTER (WHERE freight_value < 0)  AS negative_freight
FROM raw.order_items;

-- 8b. order_payments
SELECT COUNT(*) AS non_positive_payment
FROM raw.order_payments
WHERE payment_value <= 0;

-- ------------------------------------------------------------
-- 9. Отзывы, ссылающиеся на несуществующие заказы
-- ------------------------------------------------------------
SELECT COUNT(*) AS reviews_without_order
FROM raw.order_reviews r
LEFT JOIN raw.orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ------------------------------------------------------------
-- 10. Диапазон дат покупок (период данных)
-- ------------------------------------------------------------
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM raw.orders;