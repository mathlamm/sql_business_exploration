# WBS Data Science
#
# Exploration of a the Magist dataset to answer business questions with MYSQL
#
# Created 26.2.24
# Mathis Lammert
#
#

# Load db
use magist;

# 1. How many orders are there in the dataset?
SELECT COUNT(*) FROM orders;

SELECT * FROM orders;

# 2. Are orders actually delivered?
SELECT order_status, COUNT(*) FROM orders GROUP BY order_status;

# 3. Is Magist having user growth?
SELECT COUNT(order_id) count_orders, YEAR(order_purchase_timestamp) year, MONTH(order_purchase_timestamp) month
FROM orders
GROUP BY
    year,
    month
ORDER BY year DESC, month DESC;

# 4. How many products are there on the products table?
SELECT * FROM products;
SELECT COUNT(DISTINCT product_id) count_products FROM products;


# 5. Which are the categories with the most products?
SELECT
    product_category_name category,
    count(product_id) count_products
FROM products
GROUP BY
    category
ORDER BY count_products DESC;

# 6. How many of those products were present in actual transactions?
SELECT order_id, COUNT(*) FROM order_items GROUP BY order_id;
SELECT * FROM order_items;

SELECT COUNT(DISTINCT product_id) count_products FROM order_items;


# 7. What’s the price for the most expensive and cheapest products? 
SELECT
    MIN(price) lowest,
    MAX(price) most_expensive,
    AVG(price) mean_price,
FROM products p
    LEFT JOIN order_items i ON p.product_id = i.product_id;

# 8. What are the highest and lowest payment values?
SELECT MAX(payment_value), MIN(payment_value) FROM order_payments;

SELECT SUM(payment_value) highest_order
FROM order_payments GROUP BY order_id
ORDER BY highest_order DESC
LIMIT 1;



#
# ==== Answer Business Questions ====
#


# Main Questions:
# 1. Is Magist a good fit for high-end tech products?
# 2. Are orders delivered on time?


# 1.1 What categories of tech products does Magist have?
SELECT
    product_category_name category,
    count(product_id) count_products
FROM products
GROUP BY
    category
ORDER BY count_products DESC;

# -> interesting for tech are: "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"


# 1.2 How many products of these tech categories have been sold? 
#    What percentage does that represent from the overall number of products sold?
#    Added: Avg price of each category
SELECT
    product_category_name category,
    COUNT(*) n_sales,
    COUNT(*) / (
        SELECT COUNT(*)
        FROM order_items
    ) * 100 AS perc_sales,
    round(AVG(price), 2) mean_price,
    round(MIN(price), 2) min_price,
    round(MAX(price), 2) max_price
FROM products p
    RIGHT JOIN order_items i ON p.product_id = i.product_id
GROUP BY
    category
HAVING
    category IN (
        "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"
    )
ORDER BY n_sales DESC;


# 1.3 What’s the average price of the products being sold - für alle Produkte. 
SELECT
    AVG(price) mean_price
FROM products p
    RIGHT JOIN order_items i ON p.product_id = i.product_id;


# 1.4 Are expensive tech products popular?

# first create temmporary table for ordered tech items with product category info
CREATE TEMPORARY TABLE tech_order_items
SELECT *
FROM order_items i
    LEFT JOIN products p USING (product_id)
WHERE
    p.product_category_name IN (
        "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"
    );

# actal query: Are expensive tech products popular?
SELECT
    CASE
        WHEN price < 20 THEN "cheap (<20)"
        WHEN price < 50 THEN "medium (<100)"
        WHEN price < 300 THEN "expensive (<300)"
        ELSE "very expensive (>=300)"
    END AS price_cat,
    COUNT(*) n_sales,
    round(
        COUNT(*) / (
            SELECT COUNT(*)
            FROM tech_order_items
        ) * 100, 2
    ) AS perc_sales,
    round(AVG(price), 2) mean_price
FROM tech_order_items
GROUP BY
    price_cat
ORDER BY n_sales DESC;


# 2.1 How many months of data are included in the magist database?
SELECT
    MIN(order_purchase_timestamp) earlist_date,
    MAX(order_purchase_timestamp) latest_date,
    TIMESTAMPDIFF(
        MONTH, MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)
    ) months
FROM orders;


# 2.2 How many sellers are there? How many Tech sellers are there?
#     What percentage of overall sellers are Tech sellers?
SELECT
    product_category_name category,
    count(DISTINCT seller_id) n_sellers,
    round( count(DISTINCT seller_id) * 100 / (
        SELECT COUNT(DISTINCT seller_id)
        FROM
            sellers s
            JOIN order_items i USING (seller_id)
            JOIN products p USING (product_id)
    ),2) percent_sellers
FROM
    sellers s
    JOIN order_items i USING (seller_id)
    JOIN products p USING (product_id)
GROUP BY
    category
HAVING
    category IN (
        "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"
    ) 
ORDER BY
    n_sellers DESC;


# 2.3 What is the total amount earned by all sellers? 
#     What is the total amount earned by all Tech sellers?

# via price
SELECT
    product_category_name category,
    ROUND(SUM(price)) total_price,
    round(SUM(price) * 100 / (
        SELECT SUM(price)
        FROM
            sellers s
            JOIN order_items i USING (seller_id)
            JOIN products p USING (product_id)
    ),2) percent_price
FROM
    sellers s
    JOIN order_items i USING (seller_id)
    JOIN products p USING (product_id)
GROUP BY
    category
HAVING
    category IN (
        "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"
    );

# by payment

# exploring the dataset to find meaning
SELECT
    *
FROM
    order_payments pay
    JOIN order_items i USING (order_id)
    JOIN products p USING (product_id)
ORDER BY i.order_id;

#  are there multiple sellers by one order? yes. 
SELECT
    order_id,
    count(DISTINCT seller_id) n_seller,
    round(SUM(payment_value), 2) sum_payment,
    round(SUM(price), 2) sum_price
FROM
    order_payments pay
    JOIN order_items i USING (order_id)
    JOIN products p USING (product_id)
GROUP BY
    order_id
ORDER BY n_seller DESC;

# investigate the meaning of "payment"
CREATE TEMPORARY TABLE different_sellers
SELECT
    order_id,
    count(DISTINCT seller_id) n_seller,
    round(SUM(payment_value), 2) sum_payment,
    round(SUM(price), 2) sum_price
FROM
    order_payments pay
    JOIN order_items i USING (order_id)
    JOIN products p USING (product_id)
GROUP BY
    order_id
ORDER BY n_seller DESC;
-- DROP TEMPORARY TABLE different_sellers;

SELECT
    order_id,
    order_item_id,
    payment_value,
    price,
    seller_id
FROM
    order_payments pay
    JOIN order_items i USING (order_id)
    JOIN products p USING (product_id)
#WHERE order_id IN (SELECT order_id FROM different_sellers)
WHERE order_id IN ("cf5c8d9f52807cb2d2f0a0ff54c478da", "895ab968e7bb0d5659d16cd74cd1650c") 
ORDER BY order_id, order_item_id DESC;


# the tables payments and items should not be joined together directly. 
# This query combines order_id-grouping of payments (because there might be several payments per order) and price + freight value of items. and it adds up!
# so: sum(payment_value per order) = sum(prices + freight per order)
with CTE1 AS (
select order_id, sum(payment_value) from order_payments
group by order_id),
CTE2 AS (select order_id, sum(price + freight_value) from order_items
group by order_id)
select * from cte1
join cte2 using(order_id)
;


# 2.4 Can you work out the average monthly income of all sellers? 
#     Can you work out the average monthly income of Tech sellers?



# 3.1 What’s the average time between the order being placed and the product being delivered?
SELECT * FROM orders;

SELECT AVG(TIMESTAMPDIFF(
        DAY, order_purchase_timestamp, order_delivered_customer_date
    )) delivery_time_avg,
    MIN(TIMESTAMPDIFF(
        DAY, order_purchase_timestamp, order_delivered_customer_date
    )) delivery_time_min,
    MAX(TIMESTAMPDIFF(
        DAY, order_purchase_timestamp, order_delivered_customer_date
    )) delivery_time_max
FROM orders WHERE order_status = "delivered" ;

# 3.2 How many orders are delivered on time vs orders delivered with a delay?
SELECT order_status, COUNT(*), COUNT(*) * 100 / (
        SELECT count(*)
        FROM orders
    ) percent
FROM orders
GROUP BY
    order_status;
# this grouped by order status

# this is delayed vs non-delayed
CREATE TEMPORARY TABLE orders_ext  # this adds a binary category delayed vs non-delayed
SELECT
    *,
    CASE
        WHEN order_estimated_delivery_date > order_delivered_customer_date THEN "on time"
        ELSE "delayed"
    END AS delay
FROM orders;

CREATE TEMPORARY TABLE products_ext   # this adds a binary category: tech vs non-tech
SELECT
    *,
    CASE
        WHEN product_category_name IN (
            "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"
        ) THEN "tech"
        ELSE "non-tech"
    END AS tech
FROM products;

CREATE TEMPORARY TABLE products_ext2   # this adds a binary category: tech vs non-tech
SELECT
    *,
    CASE
        WHEN product_category_name IN (
            "audio", "eletronicos", "tablets_impressao_imagem", "telefonia", "pcs", "informatica_acessorios"
        ) THEN "tech"
        ELSE "non-tech"
    END AS tech
FROM products;


SELECT
    delay,
    COUNT(*) n_delay,
    ROUND(
        COUNT(*) * 100 / (
            SELECT COUNT(*)
            FROM orders
            WHERE
                order_status = "delivered"
        ), 2
    ) percent,
    AVG(
        TIMESTAMPDIFF(
            DAY, order_purchase_timestamp, order_delivered_customer_date
        )
    ) delivery_time_avg
FROM orders_ext
WHERE
    order_status = "delivered"
GROUP BY
    delay;


# 3.3 Is there any pattern for delayed orders, e.g. big products being delayed more often?
SELECT
    tech,
    delay,
    COUNT(*) n_delayed_items,
    ROUND(
        COUNT(*) * 100 / (
            SELECT COUNT(*)
            FROM
                orders
                JOIN order_items i USING (order_id)
                JOIN products_ext2 p USING (product_id)
            WHERE
                order_status = "delivered"
        ), 2
    ) percent,
    ROUND(AVG(
        TIMESTAMPDIFF(
            DAY, order_purchase_timestamp, order_delivered_customer_date
        )
    ),1) delivery_time_avg,
    ROUND(AVG(product_height_cm), 1) height,
    ROUND(AVG(product_length_cm), 1) length,
    ROUND(
        AVG(product_description_length), 1
    ) decrlength,
    ROUND(AVG(product_width_cm), 1) width,
    ROUND(AVG(product_weight_g), 1) weight
FROM
    orders_ext o
    JOIN order_items i USING (order_id)
    JOIN products_ext p USING (product_id)
WHERE
    order_status = "delivered"
GROUP BY
    tech, delay;
# cave: statistics do not refer to orders but to ordered items/products
# further reasons might be: location of seller and customer (far away or far off); nr of items shipped; seller 




# What’s the average price of tech vs no tech products
SELECT
    AVG(price) mean_price
FROM products p
    RIGHT JOIN order_items i ON p.product_id = i.product_id;