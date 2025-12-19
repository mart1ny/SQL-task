-- Проект: аналитическая система интернет-магазина
-- Задание 1: создание структуры БД с минимум 5 связанными таблицами
-- В этом файле описаны все таблицы: пользователи, категории, товары, заказы,
-- позиции заказов, отзывы и итоговая таблица monthly_reports для процедуры отчётов.
-- Сбрасываем таблицы, чтобы скрипт был идемпотентным при повторном запуске
DROP TABLE IF EXISTS monthly_reports;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;

-- Пользователи (users) — основная сущность клиентов
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    registration_date DATE NOT NULL,
    city VARCHAR(50),
    total_orders INT DEFAULT 0,
    total_spent DECIMAL(10,2) DEFAULT 0
);

-- Категории товаров с иерархией (parent_category_id)
CREATE TABLE categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT NULL,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
);

-- Товары (products) с привязкой к категориям
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(200) NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    average_rating DECIMAL(3,2) DEFAULT 0,
    created_at DATE NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- Заказы (orders) — агрегируем суммы по пользователям
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    payment_method VARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Состав заказа (order_items) — связывает заказы и товары
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_at_time DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Отзывы (reviews) — один отзыв на товар от пользователя
CREATE TABLE reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    helpful_count INT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    UNIQUE(user_id, product_id)
);

-- Итоговые ежемесячные отчёты, куда пишет процедура generate_monthly_report
CREATE TABLE monthly_reports (
    report_id INT PRIMARY KEY AUTO_INCREMENT,
    report_month DATE NOT NULL UNIQUE,
    total_orders INT NOT NULL,
    total_revenue DECIMAL(12,2) NOT NULL,
    average_order_value DECIMAL(10,2) NOT NULL,
    new_users INT NOT NULL,
    delivered_orders INT NOT NULL,
    cancelled_orders INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
