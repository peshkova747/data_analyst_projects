/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: КОСТЮК ЮЛИЯ ИСФАНДИЯРОВНА
 * Дата: 23.11.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT COUNT(id) AS players_count, -- общее количество игроков, зарегистрированных в игре;
       SUM(payer) AS payers_count, -- количество платящих игроков;
       AVG(payer) AS share_of_payers -- доля платящих игроков от общего количества пользователей, зарегистрированных в игре.
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT race, -- раса персонажа;
       SUM(payer) AS payers_count, -- количество платящих игроков этой расы;
       COUNT(id) AS players_count, -- общее количество зарегистрированных игроков этой расы;
       SUM(payer)::real / COUNT(id) AS share_of_payers -- доля платящих игроков среди всех зарегистрированных игроков этой расы.
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY race
ORDER BY share_of_payers DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT COUNT(transaction_id) AS count_transactions, -- общее количество покупок;
       SUM(amount) AS total_cost, -- суммарная стоимость всех покупок;
       MIN(amount) AS min_cost, -- минимальная стоимость покупки;
       MAX(amount) AS max_cost, -- максимальная стоимость покупки;
       AVG(amount) AS avg_cost, -- среднее значение стоимости;
       PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY amount) AS median_cost, --медиана стоимости;
       STDDEV(amount) AS stand_dev_cost -- стандартное отклонение стоимости.
FROM fantasy.events
UNION
--Исключаем нулевые покупки условием фильтрации amount <> 0
--и объединяем с резултатом предыдущего запроса 
SELECT COUNT(transaction_id) AS count_transactions, -- общее количество покупок;
       SUM(amount) AS total_cost, -- суммарная стоимость всех покупок;
       MIN(amount) AS min_cost, -- минимальная стоимость покупки;
       MAX(amount) AS max_cost, -- максимальная стоимость покупки;
       AVG(amount) AS avg_cost, -- среднее значение стоимости;
       PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY amount) AS median_cost, --медиана стоимости;
       STDDEV(amount) AS stand_dev_cost -- стандартное отклонение стоимости.
FROM fantasy.events
WHERE amount <> 0;
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
--Нулевые покупки встречаются, поскольку мин значение amount при решении прошлой задачи было равно нулю.
SELECT COUNT(*) AS total_count, --общее число покупок;
       COUNT(*) FILTER (WHERE amount = 0) AS zero_amount, -- абсолютное количество нулевых покупок;
       COUNT(*) FILTER (WHERE amount = 0)::REAL / COUNT(*) AS zero_share -- доля покупок с нулевой стоимостью от общего числа покупок.
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
SELECT i.game_items,
       COUNT(*) AS item_count, -- Общее количество внутриигровых продаж в абсолютном значении;
       COUNT(*)::REAL / (SELECT COUNT(*) FROM fantasy.events WHERE amount <> 0) AS share_of_item, -- Общее количество внутриигровых продаж в относительном значении;
       COUNT(DISTINCT id)::REAL / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount <> 0) AS share_of_players -- Долю игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей.
FROM fantasy.events AS e
JOIN fantasy.items AS i ON e.item_code = i.item_code
WHERE amount <> 0
GROUP BY i.game_items
ORDER BY item_count DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH players AS(
    SELECT r.race,
           COUNT(u.id) AS players_count --общее кол-во зарегистрированных игроков в разрезе расы;
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    GROUP BY r.race 
),
paying_players AS(
    SELECT r.race,
           COUNT(DISTINCT e.id) AS total_buyers, -- кол-во игроков, которые совершают внутриигровые покупки в разрезе расы;
           COUNT(DISTINCT e.id) FILTER (WHERE u.payer = 1) AS total_pay_buyers --кол-во платящих игроков, которые совершают внутриигровые покупки в разрезе расы;
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    WHERE amount <> 0
    GROUP BY r.race
),
player_activity AS(
    SELECT r.race,
           COUNT(e.transaction_id) AS total_purchase, -- кол-во покупок;
           SUM(amount) AS total_amount -- суммарная стоимость все покупок.
    FROM fantasy.events AS e
    JOIN fantasy.users AS u ON e.id = u.id
    JOIN fantasy.race AS r ON u.race_id = r.race_id
    WHERE amount <> 0
    GROUP BY r.race
)
SELECT p.race,
       p.players_count,
       pp.total_buyers,
       ROUND((pp.total_buyers::REAL / p.players_count)::NUMERIC, 3) AS share_of_buyers, -- доля игроков, совершающих внутриигровые покупки от общего кол-во игроков;
       ROUND((pp.total_pay_buyers::REAL / pp.total_buyers)::NUMERIC, 3) AS share_of_pay_buyers,-- доля платящих игроков среди игроков, которые совершили внутриигровые покупки.
       ROUND((pa.total_purchase::REAL / pp.total_buyers)::NUMERIC, 2) AS avg_count, -- среднее количество покупок;
       ROUND((pa.total_amount::REAL / pa.total_purchase)::NUMERIC, 2) AS avg_amount, -- средняя стоимость одной покупки;
       ROUND((pa.total_amount::REAL / pp.total_buyers)::NUMERIC, 2) AS avg_total_amount -- средняя суммарная стоимость всех покупок.
FROM players AS p
JOIN paying_players AS pp ON pp.race = p.race
JOIN player_activity AS pa ON pp.race = pa.race;


