-- 项目一：渠道与首次付费分析

-- 哪个渠道带来的用户，在注册后 30 天内更容易付费？

-- 第一步：找出每个付费用户的首次成功付款时间
SELECT
    user_id,
    MIN(paid_at) AS first_paid_at
FROM portfolio_growth.orders
WHERE order_status IN ('paid', 'refunded')
GROUP BY user_id
ORDER BY user_id;
-- 第二步：关联所有用户与首次成功付款时间
SELECT
    u.user_id,
    u.register_time,
    u.channel_id,
    p.first_paid_at
FROM portfolio_growth.users AS u
LEFT JOIN (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
) AS p
    ON u.user_id = p.user_id
ORDER BY u.user_id;
-- 第三步：保留已观察满30天的用户，标记30日内首付
SELECT
    u.user_id,
    u.register_time,
    u.channel_id,
    p.first_paid_at,
    DATE_ADD(u.register_time, INTERVAL 30 DAY) AS window_end_at,
    CASE
        WHEN p.first_paid_at >= u.register_time
         AND p.first_paid_at < DATE_ADD(u.register_time, INTERVAL 30 DAY)
        THEN 1
        ELSE 0
    END AS paid_within_30d
FROM portfolio_growth.users AS u
LEFT JOIN (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
) AS p
    ON u.user_id = p.user_id
WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
      <= '2026-01-01 00:00:00'
ORDER BY u.user_id;

-- 第四步：按渠道汇总30日首付转化率
WITH first_payment AS (
    -- 每个付费用户的首次成功付款时间
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
),
user_conversion AS (
    -- 已观察满30天的用户，以及各自的首付标记
    SELECT
        u.user_id,
        u.channel_id,
        CASE
            WHEN p.first_paid_at >= u.register_time
             AND p.first_paid_at < DATE_ADD(u.register_time, INTERVAL 30 DAY)
            THEN 1
            ELSE 0
        END AS paid_within_30d
    FROM portfolio_growth.users AS u
    LEFT JOIN first_payment AS p
        ON u.user_id = p.user_id
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
)
SELECT
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_users,
    SUM(v.paid_within_30d) AS paid_users_30d,
    ROUND(
        SUM(v.paid_within_30d) / COUNT(*) * 100,
        2
    ) AS conversion_rate_pct
FROM user_conversion AS v
JOIN portfolio_growth.marketing_channels AS c
    ON v.channel_id = c.channel_id
GROUP BY
    c.channel_id,
    c.channel_name
ORDER BY conversion_rate_pct DESC, c.channel_id;
-- 第五步：按注册月、渠道汇总30日首付转化率
WITH first_payment AS (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
),
user_conversion AS (
    SELECT
        u.user_id,
        u.register_time,
        u.channel_id,
        CASE
            WHEN p.first_paid_at >= u.register_time
             AND p.first_paid_at < DATE_ADD(u.register_time, INTERVAL 30 DAY)
            THEN 1
            ELSE 0
        END AS paid_within_30d
    FROM portfolio_growth.users AS u
    LEFT JOIN first_payment AS p
        ON u.user_id = p.user_id
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
)
SELECT
    DATE_FORMAT(v.register_time, '%Y-%m') AS register_month,
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_users,
    SUM(v.paid_within_30d) AS paid_users_30d,
    ROUND(
        SUM(v.paid_within_30d) / COUNT(*) * 100,
        2
    ) AS conversion_rate_pct
FROM user_conversion AS v
JOIN portfolio_growth.marketing_channels AS c
    ON v.channel_id = c.channel_id
GROUP BY
    DATE_FORMAT(v.register_time, '%Y-%m'),
    c.channel_id,
    c.channel_name
ORDER BY register_month, c.channel_id;