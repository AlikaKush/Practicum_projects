/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Кушкина Алика
 * Дата: 31.08.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
	COUNT (id) AS users_count,
	SUM (payer) AS payer_users,
	AVG (payer)::NUMERIC(5, 3) AS share_payer
FROM
	fantasy.users;

-- Количество платящих игроков в разресе расы
SELECT
	race,
	COUNT (id) AS users_count,
	SUM (payer) AS payer_users,
	AVG (payer)::NUMERIC(5, 3) AS share_payer
FROM
	fantasy.race AS r
JOIN fantasy.users AS u ON
	r.race_id = u.race_id
GROUP BY
    race
ORDER BY
    share_payer DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
	COUNT(amount) AS count_amount,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS MAX_amount,
	AVG(amount)::NUMERIC(7, 2) AS avg_amount,
	--среднее
	PERCENTILE_DISC(0.5) WITHIN GROUP (
	ORDER BY amount) AS mediana,
	--медиана
	STDDEV(amount)::NUMERIC(7, 2) AS stand_dev
	-- стандартное отклоненеие
FROM
	fantasy.events;
	
--Статистические показатели по полю amount БЕЗ нулевых покупок:
SELECT
	COUNT(amount) AS count_amount,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS MAX_amount,
	AVG(amount)::NUMERIC(7, 2) AS avg_amount,
	--среднее
	PERCENTILE_DISC(0.5) WITHIN GROUP (
	ORDER BY amount) AS mediana,
	--медиана
	STDDEV(amount)::NUMERIC(7, 2) AS stand_dev
	-- стандартное отклоненеие
FROM
	fantasy.events
WHERE
    amount > 0;

-- 2.2: Аномальные нулевые покупки:
SELECT 
  SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) AS count_zero,
  SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) / COUNT(amount)::numeric AS share_count_zero
FROM fantasy.events;

-- Уточнение предметов и игроков для  0 у.е. 
SELECT
	game_items,
	id,
	COUNT(*) AS count_zero_purchases
FROM
	fantasy.events AS e
JOIN fantasy.items AS i ON
	e.item_code = i.item_code
WHERE
	amount = 0
GROUP BY
	game_items,
	id
ORDER BY
	count_zero_purchases DESC;

-- 2.3: Популярные эпические предметы:
WITH item_transaction AS  
(
SELECT
	game_items,
	COUNT(transaction_id) AS count_transaction,
	--абсолютное значение внутриигровых продаж
	COUNT(DISTINCT id) AS count_distinct_id
	--количество уникальных игроков для каждого предмета
FROM
	fantasy.events AS e
JOIN fantasy.items AS i ON
	e.item_code = i.item_code
WHERE
	amount != 0
GROUP BY
	game_items
),
total_transaction_count AS
--общее количество продаж
(
SELECT
	SUM(count_transaction) AS sum_count_transaction
FROM
	item_transaction
),
all_unique AS
-- общее количество уникальных игроков
 (
SELECT
	COUNT(DISTINCT id) AS total_unique_id
FROM
	fantasy.events
WHERE
	amount != 0
  )
SELECT
	DISTINCT item_transaction.game_items,
	item_transaction.count_transaction,
	ROUND ((item_transaction.count_transaction::NUMERIC / total_transaction_count.sum_count_transaction)* 100,
	3) AS share_transaction_item,
	--относительное значение внутриигровых продаж
	ROUND ((item_transaction.count_distinct_id::NUMERIC / all_unique.total_unique_id),
	3) AS share_distinct_item
	--доля игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
FROM
	item_transaction,
	total_transaction_count,
	all_unique
ORDER BY
	share_distinct_item DESC;

-- предметы, которые ни разу не покупали:
SELECT 
 game_items
FROM fantasy.events AS e
JOIN fantasy.items AS i ON
	e.item_code = i.item_code
WHERE transaction_id IS NULL;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH
count_id_race AS 
(
SELECT
	race_id,
	COUNT (u.id) AS count_id
	--общее количество зарегистрированных игроков в каждой расе
FROM
	fantasy.users AS u
GROUP BY
	race_id
),
count_id_transaction AS 
(
SELECT
	u.race_id,
	COUNT (DISTINCT e.id) AS count_user_transaction,
	--количество покупателей 
	COUNT (DISTINCT CASE
		WHEN u.payer = 1 THEN e.id
	END) AS count_payer
	--количество игроков, которые совершили внутриигровую покупку
FROM
	fantasy.events AS e
LEFT JOIN fantasy.users AS u ON
	e.id = u.id
LEFT JOIN fantasy.race AS r ON
	u.race_id = r.race_id
WHERE
	amount > 0
GROUP BY
	u.race_id
),
share_transaction AS 
(
SELECT
	race_id,
	SUM (amount) AS sum_amount,
	-- сумма всех покупок
	COUNT (transaction_id) AS count_transaction
	--количество покупок
FROM
	fantasy.events AS e
INNER JOIN fantasy.users AS u ON
	e.id = u.id
WHERE
	amount > 0
GROUP BY
	race_id
)
SELECT
	DISTINCT fr.race,
	r.count_id,
	it.count_user_transaction,
	ROUND(it.count_user_transaction::NUMERIC / r.count_id, 2) AS share_transaction_id,
	-- доля покупателей (разделить число покупателей на число зарегистрированных игроков)
	ROUND(it.count_payer::NUMERIC / it.count_user_transaction, 2) AS share_payer_id,
	--доля платящих игроков среди игроков, которые совершили внутриигровые покупки
	ROUND(count_transaction::NUMERIC / it.count_user_transaction, 2) AS active_transaction_id,
	--среднее количество покупок на одного игрока, совершившего внутриигровые покупки
	ROUND(sum_amount::NUMERIC / count_transaction, 2) AS avg_amount,
	--средняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
	ROUND(sum_amount::NUMERIC / it.count_user_transaction, 2) AS sum_avg_amount
	--средняя суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки
FROM
	count_id_race AS r
JOIN count_id_transaction AS it ON
	r.race_id = it.race_id
JOIN share_transaction AS t ON
	r.race_id = t.race_id
JOIN fantasy.race AS fr ON
	t.race_id = fr.race_id;