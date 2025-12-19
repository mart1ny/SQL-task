-- Задание 3: аналитические запросы (10 штук), хранимая процедура и функция.
-- Ниже по порядку реализованы все пункты из списка требований.

-- 1. Топ-5 самых популярных товаров (агрегация + оконная функция ранжирования)
WITH product_totals AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(oi.quantity) AS total_quantity,
        SUM(oi.quantity * oi.price_at_time) AS total_revenue
    FROM products p
    JOIN order_items oi ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.product_name
), ranked_products AS (
    SELECT *, DENSE_RANK() OVER (ORDER BY total_quantity DESC) AS popularity_rank
    FROM product_totals
)
SELECT product_id, product_name, total_quantity, total_revenue, popularity_rank
FROM ranked_products
WHERE popularity_rank <= 5
ORDER BY popularity_rank, product_name;

-- 2. Пользователи с максимальной суммой покупок за последний месяц
SELECT
    u.user_id,
    u.username,
    u.city,
    SUM(o.total_amount) AS last_month_spent,
    COUNT(o.order_id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.user_id
WHERE o.order_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
  AND o.status IN ('processing', 'shipped', 'delivered')
GROUP BY u.user_id, u.username, u.city
ORDER BY last_month_spent DESC;

-- 3. Средний чек по месяцам за последний год (GROUP BY + фильтр по дате)
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    COUNT(*) AS order_count,
    SUM(o.total_amount) AS monthly_revenue,
    ROUND(AVG(o.total_amount), 2) AS average_check
FROM orders o
WHERE o.order_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY order_month;

-- 4. Товары, которые чаще покупают вместе (CTE + self-join order_items)
WITH paired_products AS (
    SELECT
        LEAST(oi1.product_id, oi2.product_id) AS product_a,
        GREATEST(oi1.product_id, oi2.product_id) AS product_b,
        COUNT(DISTINCT oi1.order_id) AS joint_orders
    FROM order_items oi1
    JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id < oi2.product_id
    GROUP BY LEAST(oi1.product_id, oi2.product_id), GREATEST(oi1.product_id, oi2.product_id)
)
SELECT
    pa.product_a,
    p1.product_name AS product_a_name,
    pa.product_b,
    p2.product_name AS product_b_name,
    pa.joint_orders
FROM paired_products pa
JOIN products p1 ON p1.product_id = pa.product_a
JOIN products p2 ON p2.product_id = pa.product_b
ORDER BY pa.joint_orders DESC, product_a_name
LIMIT 10;

-- 5. Воронка продаж по статусам заказов (доли через оконную функцию)
SELECT
    status,
    COUNT(*) AS orders_count,
    SUM(total_amount) AS revenue,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM orders
GROUP BY status
ORDER BY FIELD(status, 'pending', 'processing', 'shipped', 'delivered', 'cancelled');

-- 6. Категории с наибольшей выручкой
SELECT
    c.category_id,
    c.category_name,
    SUM(oi.quantity * oi.price_at_time) AS category_revenue,
    SUM(oi.quantity) AS units_sold
FROM categories c
JOIN products p ON p.category_id = c.category_id
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY c.category_id, c.category_name
ORDER BY category_revenue DESC;

-- 7. Пользователи без заказов более 30 дней (LEFT JOIN + HAVING)
SELECT
    u.user_id,
    u.username,
    u.city,
    MAX(o.order_date) AS last_order_date
FROM users u
LEFT JOIN orders o ON o.user_id = u.user_id
GROUP BY u.user_id, u.username, u.city
HAVING last_order_date IS NULL OR last_order_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY last_order_date ASC;

-- 8. Сезонность продаж (агрегация по номеру месяца и средний чек)
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date, '%m') AS month_num,
        DATE_FORMAT(order_date, '%M') AS month_name,
        SUM(total_amount) AS revenue,
        COUNT(*) AS orders_count
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%m'), DATE_FORMAT(order_date, '%M')
)
SELECT
    month_num,
    month_name,
    revenue,
    orders_count,
    ROUND(revenue / NULLIF(orders_count, 0), 2) AS average_check
FROM monthly_sales
ORDER BY month_num;

-- 9. Рейтинг городов по пользователям и сумме покупок (окно RANK)
WITH city_metrics AS (
    SELECT
        u.city,
        COUNT(DISTINCT u.user_id) AS user_count,
        COALESCE(SUM(o.total_amount), 0) AS total_revenue,
        SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders
    FROM users u
    LEFT JOIN orders o ON o.user_id = u.user_id
    GROUP BY u.city
)
SELECT
    city,
    user_count,
    total_revenue,
    delivered_orders,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM city_metrics
ORDER BY revenue_rank, city;

-- 10. Сравнение текущего месяца с предыдущим (CTE + сравнение метрик)
WITH monthly_metrics AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m-01') AS month_start,
        COUNT(*) AS total_orders,
        SUM(total_amount) AS total_revenue,
        ROUND(AVG(total_amount), 2) AS average_order_value,
        SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
), current_month AS (
    SELECT * FROM monthly_metrics
    WHERE month_start = DATE_FORMAT(CURDATE(), '%Y-%m-01')
), previous_month AS (
    SELECT * FROM monthly_metrics
    WHERE month_start = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01')
)
SELECT
    cm.month_start AS current_month,
    pm.month_start AS previous_month,
    cm.total_orders,
    pm.total_orders AS prev_total_orders,
    cm.total_orders - COALESCE(pm.total_orders, 0) AS orders_diff,
    cm.total_revenue,
    pm.total_revenue AS prev_total_revenue,
    cm.total_revenue - COALESCE(pm.total_revenue, 0) AS revenue_diff,
    cm.average_order_value,
    pm.average_order_value AS prev_average_order_value,
    cm.average_order_value - COALESCE(pm.average_order_value, 0) AS aov_diff,
    cm.delivered_orders,
    pm.delivered_orders AS prev_delivered_orders,
    cm.delivered_orders - COALESCE(pm.delivered_orders, 0) AS delivered_diff
FROM current_month cm
LEFT JOIN previous_month pm ON 1 = 1;

-- Задание 4: процедура generate_monthly_report(month DATE)
-- Считаем метрики за месяц, сохраняем их в monthly_reports и возвращаем результат.
DELIMITER //
DROP PROCEDURE IF EXISTS generate_monthly_report //
CREATE PROCEDURE generate_monthly_report(IN p_month DATE)
BEGIN
    DECLARE v_month_start DATE;
    DECLARE v_month_end DATE;
    DECLARE v_total_orders INT DEFAULT 0;
    DECLARE v_total_revenue DECIMAL(12,2) DEFAULT 0;
    DECLARE v_average_order_value DECIMAL(10,2) DEFAULT 0;
    DECLARE v_new_users INT DEFAULT 0;
    DECLARE v_delivered INT DEFAULT 0;
    DECLARE v_cancelled INT DEFAULT 0;

    SET v_month_start = DATE_FORMAT(p_month, '%Y-%m-01');
    SET v_month_end = DATE_ADD(v_month_start, INTERVAL 1 MONTH);

    SELECT
        COALESCE(COUNT(*), 0),
        COALESCE(SUM(total_amount), 0),
        COALESCE(ROUND(AVG(total_amount), 2), 0),
        COALESCE(SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END), 0)
    INTO v_total_orders, v_total_revenue, v_average_order_value, v_delivered, v_cancelled
    FROM orders
    WHERE order_date >= v_month_start AND order_date < v_month_end;

    SELECT COUNT(*)
    INTO v_new_users
    FROM users
    WHERE registration_date >= v_month_start AND registration_date < v_month_end;

    INSERT INTO monthly_reports (
        report_month,
        total_orders,
        total_revenue,
        average_order_value,
        new_users,
        delivered_orders,
        cancelled_orders
    ) VALUES (
        v_month_start,
        v_total_orders,
        v_total_revenue,
        v_average_order_value,
        v_new_users,
        v_delivered,
        v_cancelled
    )
    ON DUPLICATE KEY UPDATE
        total_orders = VALUES(total_orders),
        total_revenue = VALUES(total_revenue),
        average_order_value = VALUES(average_order_value),
        new_users = VALUES(new_users),
        delivered_orders = VALUES(delivered_orders),
        cancelled_orders = VALUES(cancelled_orders);

    SELECT
        v_month_start AS report_month,
        v_total_orders AS total_orders,
        v_total_revenue AS total_revenue,
        v_average_order_value AS average_order_value,
        v_new_users AS new_users,
        v_delivered AS delivered_orders,
        v_cancelled AS cancelled_orders;
END //
DELIMITER ;

-- Задание 5: функция calculate_user_rank(user_id INT)
-- Оценивает активность пользователя (заказы, сумма, отзывы, возраст аккаунта) и
-- возвращает ранг 1..10.
DELIMITER //
DROP FUNCTION IF EXISTS calculate_user_rank //
CREATE FUNCTION calculate_user_rank(p_user_id INT)
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_registration_date DATE;
    DECLARE v_order_count INT DEFAULT 0;
    DECLARE v_total_spent DECIMAL(12,2) DEFAULT 0;
    DECLARE v_review_count INT DEFAULT 0;
    DECLARE v_order_score DECIMAL(5,2);
    DECLARE v_spent_score DECIMAL(5,2);
    DECLARE v_review_score DECIMAL(5,2);
    DECLARE v_age_score DECIMAL(5,2);
    DECLARE v_rank_score DECIMAL(5,2);
    DECLARE v_rank INT DEFAULT 1;

    SELECT
        u.registration_date,
        COALESCE(COUNT(DISTINCT o.order_id), 0) AS order_count,
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(COUNT(DISTINCT r.review_id), 0) AS review_count
    INTO v_registration_date, v_order_count, v_total_spent, v_review_count
    FROM users u
    LEFT JOIN orders o ON o.user_id = u.user_id AND o.status <> 'cancelled'
    LEFT JOIN reviews r ON r.user_id = u.user_id
    WHERE u.user_id = p_user_id
    GROUP BY u.registration_date;

    IF v_registration_date IS NULL THEN
        RETURN 1;
    END IF;

    SET v_order_score = LEAST(v_order_count / 20, 1);
    SET v_spent_score = LEAST(v_total_spent / 2000, 1);
    SET v_review_score = LEAST(v_review_count / 10, 1);
    SET v_age_score = LEAST(DATEDIFF(CURDATE(), v_registration_date) / 365, 1);

    SET v_rank_score = v_order_score * 0.35 + v_spent_score * 0.35 + v_review_score * 0.15 + v_age_score * 0.15;
    SET v_rank = GREATEST(1, LEAST(10, CEIL(v_rank_score * 10)));

    RETURN v_rank;
END //
DELIMITER ;
