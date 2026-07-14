-- ============================================================
-- 00_create_schema.sql
-- Создание таблиц в схеме raw и загрузка данных из CSV.
-- Выручка считается через order_items.price (см. README).
-- ============================================================

-- Схемы уже созданы вручную, но оставляем на случай пересоздания.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Чистое пересоздание таблиц (безопасно перезапускать скрипт).
DROP TABLE IF EXISTS raw.order_items   CASCADE;
DROP TABLE IF EXISTS raw.order_payments CASCADE;
DROP TABLE IF EXISTS raw.order_reviews  CASCADE;
DROP TABLE IF EXISTS raw.orders         CASCADE;
DROP TABLE IF EXISTS raw.products       CASCADE;
DROP TABLE IF EXISTS raw.customers      CASCADE;

-- ------------------------------------------------------------
-- customers
-- ------------------------------------------------------------
CREATE TABLE raw.customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city            TEXT,
    customer_state           TEXT
);

-- ------------------------------------------------------------
-- orders
-- ------------------------------------------------------------
CREATE TABLE raw.orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT REFERENCES raw.customers(customer_id),
    order_status                  TEXT,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- ------------------------------------------------------------
-- products
-- ------------------------------------------------------------
CREATE TABLE raw.products (
    product_id            TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_length        INTEGER,
    product_description_length INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           INTEGER,
    product_length_cm          INTEGER,
    product_height_cm          INTEGER,
    product_width_cm           INTEGER
);

-- ------------------------------------------------------------
-- order_items  (составной ключ: order_id + order_item_id)
-- ------------------------------------------------------------
CREATE TABLE raw.order_items (
    order_id           TEXT REFERENCES raw.orders(order_id),
    order_item_id      INTEGER,
    product_id         TEXT REFERENCES raw.products(product_id),
    seller_id          TEXT,
    shipping_limit_date TIMESTAMP,
    price              NUMERIC(12,2),
    freight_value      NUMERIC(12,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- ------------------------------------------------------------
-- order_payments
-- ------------------------------------------------------------
CREATE TABLE raw.order_payments (
    order_id             TEXT REFERENCES raw.orders(order_id),
    payment_sequential   INTEGER,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        NUMERIC(12,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- ------------------------------------------------------------
-- order_reviews
-- Внимание: review_id НЕ уникален в этом датасете,
-- поэтому используем суррогатный ключ.
-- ------------------------------------------------------------
CREATE TABLE raw.order_reviews (
    review_sk               BIGSERIAL PRIMARY KEY,
    review_id               TEXT,
    order_id                TEXT,
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- ------------------------------------------------------------
-- Индексы для JOIN-ов
-- ------------------------------------------------------------
CREATE INDEX idx_orders_customer_id     ON raw.orders(customer_id);
CREATE INDEX idx_order_items_order_id   ON raw.order_items(order_id);
CREATE INDEX idx_order_items_product_id ON raw.order_items(product_id);
CREATE INDEX idx_payments_order_id      ON raw.order_payments(order_id);
CREATE INDEX idx_reviews_order_id       ON raw.order_reviews(order_id);
CREATE INDEX idx_products_category      ON raw.products(product_category_name);