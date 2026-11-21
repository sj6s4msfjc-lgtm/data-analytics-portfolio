-- 项目一：用户活跃留存分析
-- 第一步：每个用户的活跃日期，同一天只保留一行

SELECT DISTINCT
    user_id,
    DATE(event_time) AS active_date
FROM portfolio_growth.user_events
WHERE event_type <> 'register'
ORDER BY
    user_id,
    active_date;
-- 第二步：标记每个符合观察条件用户的D7留存
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
)
SELECT
    u.user_id,
    u.register_time,
    u.channel_id,
    DATE_ADD(DATE(u.register_time), INTERVAL 7 DAY) AS d7_date,
    a.active_date,
    CASE
        WHEN a.user_id IS NOT NULL THEN 1
        ELSE 0
    END AS retained_d7
FROM portfolio_growth.users AS u
LEFT JOIN active_days AS a
    ON u.user_id = a.user_id
   AND a.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 7 DAY)
WHERE DATE_ADD(DATE(u.register_time), INTERVAL 8 DAY)
      <= '2026-01-01 00:00:00'
ORDER BY u.user_id;
-- 第三步：按渠道统计D7留存率
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
)
SELECT
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_users_d7,
    COUNT(a.user_id) AS retained_users_d7,
    ROUND(
        COUNT(a.user_id) / COUNT(*) * 100,
        2
    ) AS retention_rate_d7_pct
FROM portfolio_growth.users AS u
JOIN portfolio_growth.marketing_channels AS c
    ON u.channel_id = c.channel_id
LEFT JOIN active_days AS a
    ON u.user_id = a.user_id
   AND a.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 7 DAY)
WHERE DATE_ADD(DATE(u.register_time), INTERVAL 8 DAY)
      <= '2026-01-01 00:00:00'
GROUP BY
    c.channel_id,
    c.channel_name
ORDER BY retention_rate_d7_pct DESC, c.channel_id;
-- 第四步：按渠道统计D30留存率
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
)
SELECT
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_users_d30,
    COUNT(a.user_id) AS retained_users_d30,
    ROUND(
        COUNT(a.user_id) / COUNT(*) * 100,
        2
    ) AS retention_rate_d30_pct
FROM portfolio_growth.users AS u
JOIN portfolio_growth.marketing_channels AS c
    ON u.channel_id = c.channel_id
LEFT JOIN active_days AS a
    ON u.user_id = a.user_id
   AND a.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 30 DAY)
WHERE DATE_ADD(DATE(u.register_time), INTERVAL 31 DAY)
      <= '2026-01-01 00:00:00'
GROUP BY
    c.channel_id,
    c.channel_name
ORDER BY retention_rate_d30_pct DESC, c.channel_id;
-- 第五步：使用相同用户范围，比较渠道D7、D30留存
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
)
SELECT
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_users,

    COUNT(d7.user_id) AS retained_users_d7,
    ROUND(
        COUNT(d7.user_id) / COUNT(*) * 100,
        2
    ) AS retention_rate_d7_pct,

    COUNT(d30.user_id) AS retained_users_d30,
    ROUND(
        COUNT(d30.user_id) / COUNT(*) * 100,
        2
    ) AS retention_rate_d30_pct

FROM portfolio_growth.users AS u
JOIN portfolio_growth.marketing_channels AS c
    ON u.channel_id = c.channel_id

LEFT JOIN active_days AS d7
    ON u.user_id = d7.user_id
   AND d7.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 7 DAY)

LEFT JOIN active_days AS d30
    ON u.user_id = d30.user_id
   AND d30.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 30 DAY)

WHERE DATE_ADD(DATE(u.register_time), INTERVAL 31 DAY)
      <= '2026-01-01 00:00:00'

GROUP BY
    c.channel_id,
    c.channel_name
ORDER BY retention_rate_d30_pct DESC, c.channel_id;
-- 第六步：使用相同用户范围，根据注册月，比较渠道D7、D30留存
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
)
SELECT
    DATE_FORMAT(u.register_time, '%Y-%m') AS register_month,
	c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_users,

    COUNT(d7.user_id) AS retained_users_d7,
    ROUND(
        COUNT(d7.user_id) / COUNT(*) * 100,
        2
    ) AS retention_rate_d7_pct,

    COUNT(d30.user_id) AS retained_users_d30,
    ROUND(
        COUNT(d30.user_id) / COUNT(*) * 100,
        2
    ) AS retention_rate_d30_pct

FROM portfolio_growth.users AS u
JOIN portfolio_growth.marketing_channels AS c
    ON u.channel_id = c.channel_id

LEFT JOIN active_days AS d7
    ON u.user_id = d7.user_id
   AND d7.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 7 DAY)

LEFT JOIN active_days AS d30
    ON u.user_id = d30.user_id
   AND d30.active_date =
       DATE_ADD(DATE(u.register_time), INTERVAL 30 DAY)

WHERE DATE_ADD(DATE(u.register_time), INTERVAL 31 DAY)
      <= '2026-01-01 00:00:00'
GROUP BY
    DATE_FORMAT(u.register_time, '%Y-%m'),
    c.channel_id,
    c.channel_name
ORDER BY register_month, c.channel_id;
-- 第七步：对比两个渠道8月、9月的年龄构成与D30留存
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
),
age_summary AS (
    SELECT
        DATE_FORMAT(u.register_time, '%Y-%m') AS register_month,
        c.channel_name,
        COALESCE(NULLIF(u.age_group, ''), 'unknown') AS age_group,
        COUNT(*) AS eligible_users,
        COUNT(a.user_id) AS retained_users_d30
    FROM portfolio_growth.users AS u
    JOIN portfolio_growth.marketing_channels AS c
        ON u.channel_id = c.channel_id
    LEFT JOIN active_days AS a
        ON u.user_id = a.user_id
       AND a.active_date =
           DATE_ADD(DATE(u.register_time), INTERVAL 30 DAY)
    WHERE u.channel_id IN (1, 4)
      AND u.register_time >= '2025-08-01'
      AND u.register_time < '2025-10-01'
      AND DATE_ADD(DATE(u.register_time), INTERVAL 31 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        DATE_FORMAT(u.register_time, '%Y-%m'),
        c.channel_name,
        COALESCE(NULLIF(u.age_group, ''), 'unknown')
)
SELECT
    register_month,
    channel_name,
    age_group,
    eligible_users,
    retained_users_d30,
    ROUND(
        eligible_users
        / SUM(eligible_users) OVER (
            PARTITION BY register_month, channel_name
        ) * 100,
        2
    ) AS age_share_pct,
    ROUND(
        retained_users_d30 / eligible_users * 100,
        2
    ) AS retention_rate_d30_pct
FROM age_summary
ORDER BY channel_name, age_group, register_month;
-- 第八步：对比两个渠道8月、9月的城市等级构成与D30留存
WITH active_days AS (
    SELECT DISTINCT
        user_id,
        DATE(event_time) AS active_date
    FROM portfolio_growth.user_events
    WHERE event_type <> 'register'
),
city_summary AS (
    SELECT
        DATE_FORMAT(u.register_time, '%Y-%m') AS register_month,
        c.channel_name,
        COALESCE(NULLIF(u.city_tier, ''), 'unknown') AS city_tier,
        COUNT(*) AS eligible_users,
        COUNT(a.user_id) AS retained_users_d30
    FROM portfolio_growth.users AS u
    JOIN portfolio_growth.marketing_channels AS c
        ON u.channel_id = c.channel_id
    LEFT JOIN active_days AS a
        ON u.user_id = a.user_id
       AND a.active_date =
           DATE_ADD(DATE(u.register_time), INTERVAL 30 DAY)
    WHERE u.channel_id IN (1, 4)
      AND u.register_time >= '2025-08-01'
      AND u.register_time < '2025-10-01'
      AND DATE_ADD(DATE(u.register_time), INTERVAL 31 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        DATE_FORMAT(u.register_time, '%Y-%m'),
        c.channel_name,
        COALESCE(NULLIF(u.city_tier, ''), 'unknown')
)
SELECT
    register_month,
    channel_name,
    city_tier,
    eligible_users,
    retained_users_d30,
    ROUND(
        eligible_users
        / SUM(eligible_users) OVER (
            PARTITION BY register_month, channel_name
        ) * 100,
        2
    ) AS city_share_pct,
    ROUND(
        retained_users_d30 / eligible_users * 100,
        2
    ) AS retention_rate_d30_pct
FROM city_summary
ORDER BY channel_name, city_tier, register_month;