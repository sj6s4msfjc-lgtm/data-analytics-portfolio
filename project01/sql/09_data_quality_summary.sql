-- 字段完整性检查
-- 缺失包括NULL、空字符串和只有空格的值

SELECT
    'users' AS table_name,
    'age_group' AS field_name,
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN age_group IS NULL OR TRIM(age_group) = ''
            THEN 1 ELSE 0
        END
    ) AS missing_rows,
    ROUND(
        SUM(
            CASE
                WHEN age_group IS NULL OR TRIM(age_group) = ''
                THEN 1 ELSE 0
            END
        ) / COUNT(*) * 100,
        2
    ) AS missing_rate_pct
FROM portfolio_growth.users

UNION ALL

SELECT
    'users',
    'city_tier',
    COUNT(*),
    SUM(
        CASE
            WHEN city_tier IS NULL OR TRIM(city_tier) = ''
            THEN 1 ELSE 0
        END
    ),
    ROUND(
        SUM(
            CASE
                WHEN city_tier IS NULL OR TRIM(city_tier) = ''
                THEN 1 ELSE 0
            END
        ) / COUNT(*) * 100,
        2
    )
FROM portfolio_growth.users

UNION ALL

SELECT
    'user_events',
    'device',
    COUNT(*),
    SUM(
        CASE
            WHEN device IS NULL OR TRIM(device) = ''
            THEN 1 ELSE 0
        END
    ),
    ROUND(
        SUM(
            CASE
                WHEN device IS NULL OR TRIM(device) = ''
                THEN 1 ELSE 0
            END
        ) / COUNT(*) * 100,
        2
    )
FROM portfolio_growth.user_events;