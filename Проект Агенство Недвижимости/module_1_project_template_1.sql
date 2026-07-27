/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор: Костюк Юлия Исфандияровна
 * Дата: 18.12.2025
*/
-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),

-- Используем id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
advertisement_activity AS (
    SELECT f.id, a.first_day_exposition, a.last_price, (a.last_price / f.total_area) AS price_meter,
           f.total_area, f.rooms, f.balcony, f.ceiling_height, f.floor, f.is_apartment,
        CASE
        	WHEN days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
        	WHEN days_exposition BETWEEN 31 AND 90 THEN 'до трёх месяцев'
        	WHEN days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
        	WHEN days_exposition >= 181 THEN 'более полугода'
        	ELSE 'non category'
        END AS activity_time,
        CASE
        	WHEN f.city_id = '6X8I' THEN 'Санкт-Петербург'
        	WHEN f.type_id = 'F8EM' AND f.city_id <> '6X8I' THEN 'ЛенОбл'
            ELSE 'non category'
        END AS region
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    WHERE (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018) AND f.id IN (SELECT * FROM filtered_id)
)
--  Основной запрос:
SELECT region, activity_time, COUNT(id) AS advertisement_count,
       ROUND((COUNT(id)::REAL / SUM(COUNT(id)) OVER(PARTITION BY region))::NUMERIC, 2) * 100 AS advertisement_share,
       ROUND(AVG(price_meter)::NUMERIC, 2) AS avg_price_meter,
       ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area,
       PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
       PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
       PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY floor) AS median_floor,
       ROUND(AVG(ceiling_height)::NUMERIC, 2) AS avg_ceiling_height,
       ROUND((SUM(is_apartment)::REAL / COUNT(id))::NUMERIC, 4) * 100 AS apartment_share
FROM advertisement_activity
WHERE region <> 'non category'
GROUP BY region, activity_time
ORDER BY region DESC, COUNT(id) DESC;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),

-- Используем id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
seasonality_advertisements AS (
    SELECT f.id, EXTRACT(MONTH FROM a.first_day_exposition) AS first_month_exposition, (a.last_price / f.total_area) AS price_meter, f.total_area,
           CASE
               WHEN a.days_exposition IS NOT NULL THEN EXTRACT(MONTH FROM a.first_day_exposition + (a.days_exposition * INTERVAL '1 day'))
               ELSE NULL
           END AS last_month_exposition,
           CASE
        	WHEN f.city_id = '6X8I' THEN 'Санкт-Петербург'
        	WHEN f.type_id = 'F8EM' AND f.city_id <> '6X8I' THEN 'ЛенОбл'
            ELSE 'non category'
        END AS region
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    WHERE (EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018) AND f.id IN (SELECT * FROM filtered_id) 
),
month_advertising AS (
    SELECT first_month_exposition, region, COUNT(id) AS count_advertisement,
           ROUND(AVG(price_meter)::NUMERIC, 2) AS avg_price_meter,
           ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area
    FROM seasonality_advertisements
    WHERE region <> 'non category'
    GROUP BY first_month_exposition, region
    ORDER BY first_month_exposition
),
month_removal AS (
    SELECT last_month_exposition, region, COUNT(id) AS count_advertisement,
           ROUND(AVG(price_meter)::NUMERIC, 2) AS avg_price_meter,
           ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area
    FROM seasonality_advertisements
    WHERE region <> 'non category' AND last_month_exposition IS NOT NULL
    GROUP BY last_month_exposition, region
    ORDER BY last_month_exposition
)
--  Основной запрос:
SELECT ma.first_month_exposition AS month_, ma.region, 
       ma.count_advertisement, mr.count_advertisement AS count_sales,
       ma.avg_price_meter, mr.avg_price_meter AS avg_price_meter_sales,
       ma.avg_total_area, mr.avg_total_area AS avg_total_area_sales
FROM month_advertising AS ma
FULL JOIN month_removal AS mr ON ma.first_month_exposition = mr.last_month_exposition AND ma.region = mr.region;
