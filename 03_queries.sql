-- =====================================================
-- Аналитические запросы: 10 бизнес-вопросов и ответы на них
-- Каждый запрос решает конкретную задачу бизнеса.
-- =====================================================

----------------------------------------------------------------
-- 1. ТОП-10 товаров по выручке
-- Задача: понять, что приносит магазину больше всего денег.
----------------------------------------------------------------
SELECT p.product_name,
       p.category,
       SUM(oi.quantity)                    AS units_sold,
       ROUND(SUM(oi.quantity * oi.price), 2) AS revenue
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'доставлен'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY revenue DESC
LIMIT 10;

----------------------------------------------------------------
-- 2. Выручка по месяцам и её динамика (окно-функция)
-- Задача: увидеть рост или падение выручки месяц к месяцу.
----------------------------------------------------------------
WITH monthly AS (
    SELECT strftime('%Y-%m', o.order_date) AS month,
           SUM(oi.quantity * oi.price)     AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'доставлен'
    GROUP BY month
)
SELECT month,
       revenue,
       ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS revenue_change,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1)         AS change_pct
FROM monthly
ORDER BY month;

----------------------------------------------------------------
-- 3. RFM-подобная сегментация клиентов
-- Задача: выделить самых ценных клиентов для рассылки и акций.
----------------------------------------------------------------
WITH stats AS (
    SELECT c.customer_id,
           c.full_name,
           MAX(o.order_date)                                    AS last_order,
           COUNT(DISTINCT o.order_id)                           AS orders_cnt,
           SUM(oi.quantity * oi.price)                          AS lifetime_value
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id AND o.status = 'доставлен'
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_id
)
SELECT full_name,
       last_order,
       orders_cnt,
       ROUND(lifetime_value, 2) AS lifetime_value,
       CASE
           WHEN lifetime_value >= 300000 THEN 'VIP'
           WHEN lifetime_value >= 150000 THEN 'Постоянный'
           WHEN lifetime_value >=  50000 THEN 'Активный'
           ELSE 'Новичок'
       END AS segment
FROM stats
ORDER BY lifetime_value DESC;

----------------------------------------------------------------
-- 4. Коэффициент отмены заказов по месяцам
-- Задача: отследить качество логистики и спроса.
----------------------------------------------------------------
SELECT strftime('%Y-%m', order_date) AS month,
       COUNT(*)                                                              AS total_orders,
       SUM(CASE WHEN status = 'отменён' THEN 1 ELSE 0 END)                   AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN status = 'отменён' THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                                  AS cancel_rate_pct
FROM orders
GROUP BY month
ORDER BY month;

----------------------------------------------------------------
-- 5. Средний чек по городам
-- Задача: понять, где покупают дорого, где — мало и часто.
----------------------------------------------------------------
SELECT c.city,
       COUNT(DISTINCT o.order_id)                                            AS orders_cnt,
       ROUND(SUM(oi.quantity * oi.price) / COUNT(DISTINCT o.order_id), 2)    AS avg_check
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'доставлен'
GROUP BY c.city
HAVING COUNT(DISTINCT o.order_id) >= 10
ORDER BY avg_check DESC;

----------------------------------------------------------------
-- 6. Повторные покупки: доля клиентов с 2+ заказами
-- Задача: оценка удержания (retention).
----------------------------------------------------------------
WITH per_customer AS (
    SELECT customer_id, COUNT(*) AS orders_cnt
    FROM orders
    WHERE status = 'доставлен'
    GROUP BY customer_id
)
SELECT COUNT(*)                                                              AS total_buyers,
       SUM(CASE WHEN orders_cnt >= 2 THEN 1 ELSE 0 END)                      AS repeat_buyers,
       ROUND(100.0 * SUM(CASE WHEN orders_cnt >= 2 THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                                  AS repeat_rate_pct
FROM per_customer;

----------------------------------------------------------------
-- 7. Категории: выручка, средняя цена позиции, доля рынка
-- Задача: какие категории — локомотивы, какие — балласт.
----------------------------------------------------------------
SELECT p.category,
       ROUND(SUM(oi.quantity * oi.price), 2)                                 AS revenue,
       ROUND(AVG(oi.price), 2)                                               AS avg_item_price,
       ROUND(100.0 * SUM(oi.quantity * oi.price)
             / (SELECT SUM(quantity * price) FROM order_items), 1)          AS revenue_share_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o   ON o.order_id = oi.order_id AND o.status = 'доставлен'
GROUP BY p.category
ORDER BY revenue DESC;

----------------------------------------------------------------
-- 8. Товары, которые часто покупают вместе (пары)
-- Задача: основа для рекомендаций «с этим часто берут».
----------------------------------------------------------------
SELECT p1.product_name AS product_1,
       p2.product_name AS product_2,
       COUNT(*)        AS times_together
FROM order_items a
JOIN order_items b ON a.order_id = b.order_id AND a.item_id < b.item_id
JOIN products p1   ON p1.product_id = a.product_id
JOIN products p2   ON p2.product_id = b.product_id
GROUP BY p1.product_id, p2.product_id
HAVING COUNT(*) >= 5
ORDER BY times_together DESC
LIMIT 10;

----------------------------------------------------------------
-- 9. «Спящие» клиенты: не покупали 90+ дней, но раньше покупали
-- Задача: база для реактивационной рассылки.
----------------------------------------------------------------
SELECT c.customer_id,
       c.full_name,
       c.email,
       MAX(o.order_date) AS last_order,
       CAST(julianday('2024-12-31') - julianday(MAX(o.order_date)) AS INTEGER) AS days_since
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'доставлен'
GROUP BY c.customer_id
HAVING days_since >= 90
ORDER BY days_since DESC;

----------------------------------------------------------------
-- 10. AOV (средний чек) по месяцам + среднее число позиций
-- Задача: следить за «здоровьем» выручки на уровне чека.
----------------------------------------------------------------
SELECT strftime('%Y-%m', o.order_date)                        AS month,
       ROUND(SUM(oi.quantity * oi.price) / COUNT(DISTINCT o.order_id), 2) AS aov,
       ROUND(COUNT(oi.item_id) * 1.0 / COUNT(DISTINCT o.order_id), 2)     AS items_per_order
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'доставлен'
GROUP BY month
ORDER BY month;
