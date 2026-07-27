--QL-запросы в DataLens для визуализации следующих метрик:
--DAU (от англ. daily active users) — количество активных пользователей за день.
SELECT log_date,
       COUNT(DISTINCT user_id) AS DAU
FROM analytics_events ae
JOIN cities c ON ae.city_id = c.city_id
WHERE (log_date > '2021-04-30') AND (log_date < '2021-07-01') AND (order_id IS NOT NULL) AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date
LIMIT 10;

--Conversion Rate — коэффициент конверсии.
SELECT log_date,
       ROUND((COUNT(DISTINCT user_id) filter (WHERE order_id IS NOT NULL ))/COUNT(DISTINCT user_id)::numeric, 2) AS CR
FROM analytics_events ae
JOIN cities c ON ae.city_id = c.city_id
WHERE (log_date > '2021-04-30') AND (log_date < '2021-07-01') AND city_name = 'Саранск'
GROUP BY log_date
ORDER BY log_date
LIMIT 10;

--Средний чек — средняя сумма покупки на пользователя.
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT *,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

SELECT DATE_TRUNC('month', log_date)::date as "Месяц",
    COUNT(DISTINCT(order_id)) AS "Количество заказов",
    ROUND(SUM(commission_revenue)::numeric, 2) AS "Сумма комиссии",
    ROUND((SUM(commission_revenue) / COUNT(DISTINCT(order_id)))::numeric, 2) as "Средний чек"
FROM orders
GROUP BY DATE_TRUNC('month', log_date)::date
ORDER BY DATE_TRUNC('month', log_date)::date;

--LTV (от англ. lifetime value) — совокупная ценность клиента за период.
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.visitor_uuid,
            analytics_events.user_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

         
SELECT orders.rest_id,
       chain AS "Название сети",
       type AS "Тип кухни",
       ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM orders
JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id 
GROUP BY orders.rest_id, chain, type
ORDER BY LTV DESC
LIMIT 3;

--Retention Rate — коэффициент удержания пользователей.
-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'), 

-- Рассчитываем два ресторана с наибольшим LTV 
top_ltv_restaurants AS
    (SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2)

SELECT chain AS "Название сети",
       name AS "Название блюда",
       spicy,
       fish,
       meat,
       ROUND(SUM(orders.commission_revenue)::numeric, 2) AS LTV
FROM orders
JOIN top_ltv_restaurants ON orders.rest_id = top_ltv_restaurants.rest_id
JOIN dishes ON top_ltv_restaurants.rest_id = dishes.rest_id AND orders.object_id = dishes.object_id
GROUP BY 1, 2, 3, 4, 5
ORDER BY LTV DESC
LIMIT 5;