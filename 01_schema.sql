-- =====================================================
-- Проект: Аналитика продаж интернет-магазина
-- СУБД: SQLite (совместимо с PostgreSQL почти без правок)
-- Запуск: sqlite3 shop.db < 01_schema.sql
-- =====================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- Клиенты
CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    full_name     TEXT NOT NULL,
    city          TEXT NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    register_date TEXT NOT NULL  -- дата регистрации (ISO 8601)
);

-- Товары
CREATE TABLE products (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category     TEXT NOT NULL,
    price        REAL NOT NULL CHECK (price > 0)
);

-- Заказы
CREATE TABLE orders (
    order_id     INTEGER PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date   TEXT NOT NULL,
    status       TEXT NOT NULL CHECK (status IN ('доставлен', 'в пути', 'отменён'))
);

-- Состав заказов (позиции)
CREATE TABLE order_items (
    item_id    INTEGER PRIMARY KEY,
    order_id   INTEGER NOT NULL REFERENCES orders(order_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    price      REAL NOT NULL  -- цена на момент продажи
);

-- Индексы для ускорения частых JOIN-ов
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_order     ON order_items(order_id);
CREATE INDEX idx_items_product   ON order_items(product_id);
CREATE INDEX idx_orders_date     ON orders(order_date);
