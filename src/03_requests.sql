-- Request №1
WITH
rent_stats AS (
    SELECT
        id_realtor,
        COUNT(id_contract) AS rent_count,
        SUM(monthly_price * duration_months) * 10000 AS rent_total_sum
    FROM rent_contract
    GROUP BY id_realtor
),

sale_stats AS (
    SELECT
        id_realtor,
        COUNT(id_contract) AS sale_count,
        SUM(sale_amount) * 1000000 AS sale_total_sum
    FROM purchase_contract
    GROUP BY id_realtor
),


---- Limit
last_contracts AS (
    SELECT
        id_realtor,
        conclusion_date,
        'RENT' as contract_type
    FROM rent_contract
    UNION ALL
    SELECT
        id_realtor,
        conclusion_date,
        'SALE' as contract_type
    FROM purchase_contract
),

last_contract_info AS (
    SELECT
        id_realtor,
        conclusion_date as last_conclusion_date,
        contract_type as last_contract_type
    FROM (
        SELECT
            id_realtor,
            conclusion_date,
            contract_type,
            ROW_NUMBER() OVER (PARTITION BY id_realtor ORDER BY conclusion_date DESC) AS rn
        FROM last_contracts
    ) sub
    WHERE rn = 1
),

payment_stats AS (
    SELECT
        id_recipient_employee AS id_realtor,
        SUM(amount) * 10000 AS total_payments
    FROM payment_document
    WHERE document_type = 'OUTGOING'
    GROUP BY id_recipient_employee
)

SELECT
    e.full_name AS "ФИО",
    COALESCE(rs.rent_count, 0) AS "Число договоров аренды",
    COALESCE(rs.rent_total_sum, 0) AS "Сумма договоров аренды",
    COALESCE(ss.sale_count, 0) AS "Число договоров продажи",
    COALESCE(ss.sale_total_sum, 0) AS "Сумма договоров продажи",
    lc.last_conclusion_date AS "Дата последнего договора",
    COALESCE(lc.last_contract_type, 'Нет договоров') AS "Тип последнего договора",
    COALESCE(ps.total_payments, 0) AS "Сумма выплат риелтору"
FROM employee e
LEFT JOIN rent_stats rs ON e.id_employee = rs.id_realtor
LEFT JOIN sale_stats ss ON e.id_employee = ss.id_realtor
LEFT JOIN last_contract_info lc ON e.id_employee = lc.id_realtor
LEFT JOIN payment_stats ps ON e.id_employee = ps.id_realtor
WHERE e.role_code = 'REALTOR'
ORDER BY e.full_name;

-- Request №2
WITH housing_info AS (
    SELECT
        h.id_housing,
        r.name AS region_name,
        h.type AS housing_type,
        h.address,
        h.floor,
        h.house_number,
        h.square,
        h.ceiling_height,

        cc.conclusion_date AS listed_date,
        (cc.property_price::numeric * 1000000) AS total_price,
        (cc.property_price::numeric * 1000000 / h.square) AS price_per_metre,

        CASE
            WHEN pc.id_contract IS NOT NULL THEN 'Да'
            ELSE 'Нет'
        END AS is_sold

    FROM housing h
    JOIN region r ON h.id_region = r.id_region
    JOIN cooperation_contract cc ON h.id_housing = cc.id_housing AND cc.contract_type = 'SALE'
    LEFT JOIN purchase_contract pc ON h.id_housing = pc.id_housing
)

SELECT
    region_name AS "Регион",
    housing_type AS "Тип жилья",
    address AS "Адрес",
    floor AS "Этаж",
    house_number AS "Номер",
    ceiling_height AS "Высота потолков",
    listed_date AS "Дата выставления на продажу",
    is_sold AS "Продано",
    ROUND(price_per_metre, 2) AS "Цена/метр^2",
    square AS "Площадь",
    total_price AS "Цена",

    CASE
        WHEN MAX(total_price) OVER (PARTITION BY region_name) > total_price THEN 'Да'
        ELSE 'Нет'
    END AS "Есть ли более дорогое"

FROM housing_info
ORDER BY price_per_metre;

-- Request №4
WITH month_stats AS (
    SELECT
        e.id_employee,
        e.full_name,
        EXTRACT(MONTH FROM pd.document_date) AS month_num,
        COUNT(DISTINCT CASE WHEN pd.id_rent_contract IS NOT NULL THEN pd.id_rent_contract END) AS rent_count,
        SUM(CASE WHEN pd.id_rent_contract IS NOT NULL AND pd.document_type = 'OUTGOING' THEN pd.amount::numeric * 10000 ELSE 0 END) AS rent_sum,
        COUNT(DISTINCT CASE WHEN pd.id_purchase_contract IS NOT NULL THEN pd.id_purchase_contract END) AS sale_count,
        SUM(CASE WHEN pd.id_purchase_contract IS NOT NULL AND pd.document_type = 'OUTGOING' THEN pd.amount::numeric * 10000 ELSE 0 END) AS sale_sum
    FROM employee e
    LEFT JOIN payment_document pd ON e.id_employee = pd.id_recipient_employee
        AND EXTRACT(YEAR FROM pd.document_date) = EXTRACT(YEAR FROM CURRENT_DATE) - 1
    WHERE e.role_code = 'REALTOR'
    GROUP BY e.id_employee, e.full_name, EXTRACT(MONTH FROM pd.document_date)
)
SELECT
    full_name AS "ФИО",
    COALESCE(SUM(CASE WHEN month_num = 1 THEN rent_count END), 0) AS "Count(r)_01",
    COALESCE(SUM(CASE WHEN month_num = 1 THEN rent_sum END), 0) AS "Reward(r)_01",
    COALESCE(SUM(CASE WHEN month_num = 1 THEN sale_count END), 0) AS "Count(p)_01",
    COALESCE(SUM(CASE WHEN month_num = 1 THEN sale_sum END), 0) AS "Reward(p)_01",

    COALESCE(SUM(CASE WHEN month_num = 2 THEN rent_count END), 0) AS "Count(r)_02",
    COALESCE(SUM(CASE WHEN month_num = 2 THEN rent_sum END), 0) AS "Reward(r)_02",
    COALESCE(SUM(CASE WHEN month_num = 2 THEN sale_count END), 0) AS "Count(p)_02",
    COALESCE(SUM(CASE WHEN month_num = 2 THEN sale_sum END), 0) AS "Reward(p)_02",

    COALESCE(SUM(CASE WHEN month_num = 3 THEN rent_count END), 0) AS "Count(r)_03",
    COALESCE(SUM(CASE WHEN month_num = 3 THEN rent_sum END), 0) AS "Reward(r)_03",
    COALESCE(SUM(CASE WHEN month_num = 3 THEN sale_count END), 0) AS "Count(p)_03",
    COALESCE(SUM(CASE WHEN month_num = 3 THEN sale_sum END), 0) AS "Reward(p)_03",

    COALESCE(SUM(CASE WHEN month_num = 4 THEN rent_count END), 0) AS "Count(r)_04",
    COALESCE(SUM(CASE WHEN month_num = 4 THEN rent_sum END), 0) AS "Reward(r)_04",
    COALESCE(SUM(CASE WHEN month_num = 4 THEN sale_count END), 0) AS "Count(p)_04",
    COALESCE(SUM(CASE WHEN month_num = 4 THEN sale_sum END), 0) AS "Reward(p)_04",

    COALESCE(SUM(CASE WHEN month_num = 5 THEN rent_count END), 0) AS "Count(r)_05",
    COALESCE(SUM(CASE WHEN month_num = 5 THEN rent_sum END), 0) AS "Reward(r)_05",
    COALESCE(SUM(CASE WHEN month_num = 5 THEN sale_count END), 0) AS "Count(p)_05",
    COALESCE(SUM(CASE WHEN month_num = 5 THEN sale_sum END), 0) AS "Reward(p)_05",

    COALESCE(SUM(CASE WHEN month_num = 6 THEN rent_count END), 0) AS "Count(r)_06",
    COALESCE(SUM(CASE WHEN month_num = 6 THEN rent_sum END), 0) AS "Reward(r)_06",
    COALESCE(SUM(CASE WHEN month_num = 6 THEN sale_count END), 0) AS "Count(p)_06",
    COALESCE(SUM(CASE WHEN month_num = 6 THEN sale_sum END), 0) AS "Reward(p)_06",

    COALESCE(SUM(CASE WHEN month_num = 7 THEN rent_count END), 0) AS "Count(r)_07",
    COALESCE(SUM(CASE WHEN month_num = 7 THEN rent_sum END), 0) AS "Reward(r)_07",
    COALESCE(SUM(CASE WHEN month_num = 7 THEN sale_count END), 0) AS "Count(p)_07",
    COALESCE(SUM(CASE WHEN month_num = 7 THEN sale_sum END), 0) AS "Reward(p)_07",

    COALESCE(SUM(CASE WHEN month_num = 8 THEN rent_count END), 0) AS "Count(r)_08",
    COALESCE(SUM(CASE WHEN month_num = 8 THEN rent_sum END), 0) AS "Reward(r)_08",
    COALESCE(SUM(CASE WHEN month_num = 8 THEN sale_count END), 0) AS "Count(p)_08",
    COALESCE(SUM(CASE WHEN month_num = 8 THEN sale_sum END), 0) AS "Reward(p)_08",

    COALESCE(SUM(CASE WHEN month_num = 9 THEN rent_count END), 0) AS "Count(r)_09",
    COALESCE(SUM(CASE WHEN month_num = 9 THEN rent_sum END), 0) AS "Reward(r)_09",
    COALESCE(SUM(CASE WHEN month_num = 9 THEN sale_count END), 0) AS "Count(p)_09",
    COALESCE(SUM(CASE WHEN month_num = 9 THEN sale_sum END), 0) AS "Reward(p)_09",

    COALESCE(SUM(CASE WHEN month_num = 10 THEN rent_count END), 0) AS "Count(r)_10",
    COALESCE(SUM(CASE WHEN month_num = 10 THEN rent_sum END), 0) AS "Reward(r)_10",
    COALESCE(SUM(CASE WHEN month_num = 10 THEN sale_count END), 0) AS "Count(p)_10",
    COALESCE(SUM(CASE WHEN month_num = 10 THEN sale_sum END), 0) AS "Reward(p)_10",

    COALESCE(SUM(CASE WHEN month_num = 11 THEN rent_count END), 0) AS "Count(r)_11",
    COALESCE(SUM(CASE WHEN month_num = 11 THEN rent_sum END), 0) AS "Reward(r)_11",
    COALESCE(SUM(CASE WHEN month_num = 11 THEN sale_count END), 0) AS "Count(p)_11",
    COALESCE(SUM(CASE WHEN month_num = 11 THEN sale_sum END), 0) AS "Reward(p)_11",

    COALESCE(SUM(CASE WHEN month_num = 12 THEN rent_count END), 0) AS "Count(r)_12",
    COALESCE(SUM(CASE WHEN month_num = 12 THEN rent_sum END), 0) AS "Reward(r)_12",
    COALESCE(SUM(CASE WHEN month_num = 12 THEN sale_count END), 0) AS "Count(p)_12",
    COALESCE(SUM(CASE WHEN month_num = 12 THEN sale_sum END), 0) AS "Reward(p)_12"
FROM month_stats
GROUP BY id_employee, full_name
ORDER BY full_name;

-- Request №5
WITH RECURSIVE region_hierarchy AS (
    SELECT
        id_region,
        name AS region_name,
        description,
        id_parent,
        name AS top_parent_name,
        id_region AS original_id,
        ARRAY[id_region] AS path
    FROM region

    UNION ALL

    SELECT
        rh.id_region,
        rh.region_name,
        rh.description,
        r.id_parent,
        r.name,
        rh.original_id,
        rh.path || r.id_region
    FROM region r
    JOIN region_hierarchy rh ON r.id_region = rh.id_parent
    WHERE NOT r.id_region = ANY(rh.path)
)
SELECT
    rh.region_name AS "Название",
    rh.description AS "Описание",
    COALESCE(p.name, 'Нет') AS "Родитель",
    rh.top_parent_name AS "Самый верхний родитель"
FROM region_hierarchy rh
LEFT JOIN region orig ON rh.original_id = orig.id_region
LEFT JOIN region p ON orig.id_parent = p.id_region
WHERE rh.id_parent IS NULL
ORDER BY rh.top_parent_name, rh.region_name;