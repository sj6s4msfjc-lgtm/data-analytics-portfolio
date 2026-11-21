-- 项目一：转化漏斗分析

-- 第一步：查找每个用户首次开始试听的时间
SELECT
    user_id,
    MIN(event_time) AS first_trial_start_at
FROM portfolio_growth.user_events
WHERE event_type = 'trial_start'
GROUP BY user_id
ORDER BY user_id;
-- 第二步：找出已观察满30天用户的首次有效试听时间
SELECT
    u.user_id,
    u.register_time,
    u.channel_id,
    MIN(e.event_time) AS first_trial_start_at
FROM portfolio_growth.users AS u
LEFT JOIN portfolio_growth.user_events AS e
    ON u.user_id = e.user_id
   AND e.event_type = 'trial_start'
   AND e.event_time >= u.register_time
   AND e.event_time < DATE_ADD(u.register_time, INTERVAL 30 DAY)
WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
      <= '2026-01-01 00:00:00'
GROUP BY
    u.user_id,
    u.register_time,
    u.channel_id
ORDER BY u.user_id;
-- 第三步：在有效开始试听之后，查找首次完成试听时间
WITH trial_start AS (
    -- 上一步的结果，每个符合观察条件的用户一行
    SELECT
        u.user_id,
        u.register_time,
        u.channel_id,
        MIN(e.event_time) AS first_trial_start_at
    FROM portfolio_growth.users AS u
    LEFT JOIN portfolio_growth.user_events AS e
        ON u.user_id = e.user_id
       AND e.event_type = 'trial_start'
       AND e.event_time >= u.register_time
       AND e.event_time < DATE_ADD(u.register_time, INTERVAL 30 DAY)
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        u.user_id,
        u.register_time,
        u.channel_id
)
SELECT
    t.user_id,
    t.register_time,
    t.channel_id,
    t.first_trial_start_at,
    MIN(e.event_time) AS first_trial_complete_at
FROM trial_start AS t
LEFT JOIN portfolio_growth.user_events AS e
    ON t.user_id = e.user_id
   AND e.event_type = 'trial_complete'
   AND e.event_time > t.first_trial_start_at
   AND e.event_time < DATE_ADD(t.register_time, INTERVAL 30 DAY)
GROUP BY
    t.user_id,
    t.register_time,
    t.channel_id,
    t.first_trial_start_at
ORDER BY t.user_id;
-- 第四步：关联首次付款，标记完整试听路径转化
WITH trial_start AS (
    SELECT
        u.user_id,
        u.register_time,
        u.channel_id,
        MIN(e.event_time) AS first_trial_start_at
    FROM portfolio_growth.users AS u
    LEFT JOIN portfolio_growth.user_events AS e
        ON u.user_id = e.user_id
       AND e.event_type = 'trial_start'
       AND e.event_time >= u.register_time
       AND e.event_time < DATE_ADD(u.register_time, INTERVAL 30 DAY)
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        u.user_id,
        u.register_time,
        u.channel_id
),
trial_complete AS (
    SELECT
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at,
        MIN(e.event_time) AS first_trial_complete_at
    FROM trial_start AS t
    LEFT JOIN portfolio_growth.user_events AS e
        ON t.user_id = e.user_id
       AND e.event_type = 'trial_complete'
       AND e.event_time > t.first_trial_start_at
       AND e.event_time < DATE_ADD(t.register_time, INTERVAL 30 DAY)
    GROUP BY
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at
),
first_payment AS (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
)
SELECT
    t.user_id,
    t.register_time,
    t.channel_id,
    t.first_trial_start_at,
    t.first_trial_complete_at,
    p.first_paid_at,
    CASE
        WHEN p.first_paid_at >= t.register_time
         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
        THEN 1
        ELSE 0
    END AS paid_within_30d,
    CASE
        WHEN p.first_paid_at > t.first_trial_complete_at
         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
        THEN 1
        ELSE 0
    END AS funnel_paid_30d
FROM trial_complete AS t
LEFT JOIN first_payment AS p
    ON t.user_id = p.user_id
ORDER BY t.user_id;
-- 第五步
WITH trial_start AS (
    SELECT
        u.user_id,
        u.register_time,
        u.channel_id,
        MIN(e.event_time) AS first_trial_start_at
    FROM portfolio_growth.users AS u
    LEFT JOIN portfolio_growth.user_events AS e
        ON u.user_id = e.user_id
       AND e.event_type = 'trial_start'
       AND e.event_time >= u.register_time
       AND e.event_time < DATE_ADD(u.register_time, INTERVAL 30 DAY)
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        u.user_id,
        u.register_time,
        u.channel_id
),
trial_complete AS (
    SELECT
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at,
        MIN(e.event_time) AS first_trial_complete_at
    FROM trial_start AS t
    LEFT JOIN portfolio_growth.user_events AS e
        ON t.user_id = e.user_id
       AND e.event_type = 'trial_complete'
       AND e.event_time > t.first_trial_start_at
       AND e.event_time < DATE_ADD(t.register_time, INTERVAL 30 DAY)
    GROUP BY
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at
),
first_payment AS (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
),
user_funnel AS (
	SELECT
	    t.user_id,
	    t.register_time,
	    t.channel_id,
	    t.first_trial_start_at,
	    t.first_trial_complete_at,
	    p.first_paid_at,
	    CASE
	        WHEN p.first_paid_at >= t.register_time
	         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
	        THEN 1
	        ELSE 0
	    END AS paid_within_30d,
	    CASE
	        WHEN p.first_paid_at > t.first_trial_complete_at
	         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
	        THEN 1
	        ELSE 0
	    END AS funnel_paid_30d
	FROM trial_complete AS t
	LEFT JOIN first_payment AS p
	    ON t.user_id = p.user_id
)
SELECT
	DATE_FORMAT(f.register_time, '%Y-%m') AS register_month,
    c.channel_id,
    c.channel_name,

    COUNT(*) AS eligible_users,
    COUNT(f.first_trial_start_at) AS trial_start_users,
    COUNT(f.first_trial_complete_at) AS trial_complete_users,
    SUM(f.funnel_paid_30d) AS funnel_paid_users,
    SUM(f.paid_within_30d) AS all_paid_users_30d,

    ROUND(
        COUNT(f.first_trial_start_at) / COUNT(*) * 100,
        2
    ) AS register_to_trial_pct,

    ROUND(
        COUNT(f.first_trial_complete_at)
        / NULLIF(COUNT(f.first_trial_start_at), 0) * 100,
        2
    ) AS trial_to_complete_pct,

    ROUND(
        SUM(f.funnel_paid_30d)
        / NULLIF(COUNT(f.first_trial_complete_at), 0) * 100,
        2
    ) AS complete_to_first_pay_pct

FROM user_funnel AS f
JOIN portfolio_growth.marketing_channels AS c
    ON f.channel_id = c.channel_id
WHERE f.register_time >= '2025-08-01'
  AND f.register_time < '2025-10-01'
GROUP BY
    DATE_FORMAT(f.register_time, '%Y-%m'),
    c.channel_id,
    c.channel_name
ORDER BY register_month, c.channel_id;

-- 社交广告8月、9月的30日首付路径分布
WITH trial_start AS (
    SELECT
        u.user_id,
        u.register_time,
        u.channel_id,
        MIN(e.event_time) AS first_trial_start_at
    FROM portfolio_growth.users AS u
    LEFT JOIN portfolio_growth.user_events AS e
        ON u.user_id = e.user_id
       AND e.event_type = 'trial_start'
       AND e.event_time >= u.register_time
       AND e.event_time < DATE_ADD(u.register_time, INTERVAL 30 DAY)
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        u.user_id,
        u.register_time,
        u.channel_id
),
trial_complete AS (
    SELECT
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at,
        MIN(e.event_time) AS first_trial_complete_at
    FROM trial_start AS t
    LEFT JOIN portfolio_growth.user_events AS e
        ON t.user_id = e.user_id
       AND e.event_type = 'trial_complete'
       AND e.event_time > t.first_trial_start_at
       AND e.event_time < DATE_ADD(t.register_time, INTERVAL 30 DAY)
    GROUP BY
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at
),
first_payment AS (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
),
user_funnel AS (
	SELECT
	    t.user_id,
	    t.register_time,
	    t.channel_id,
	    t.first_trial_start_at,
	    t.first_trial_complete_at,
	    p.first_paid_at,
	    CASE
	        WHEN p.first_paid_at >= t.register_time
	         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
	        THEN 1
	        ELSE 0
	    END AS paid_within_30d,
	    CASE
	        WHEN p.first_paid_at > t.first_trial_complete_at
	         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
	        THEN 1
	        ELSE 0
	    END AS funnel_paid_30d
	FROM trial_complete AS t
	LEFT JOIN first_payment AS p
	    ON t.user_id = p.user_id
)
SELECT
    DATE_FORMAT(f.register_time, '%Y-%m') AS register_month,
    CASE
        WHEN f.funnel_paid_30d = 1
            THEN '完成试听后首付'
        WHEN f.first_trial_start_at IS NULL
          OR f.first_trial_start_at >= f.first_paid_at
            THEN '首付前无试听开始记录'
        ELSE '开始试听后、完成前首付'
    END AS payment_path,
    COUNT(*) AS paid_users
FROM user_funnel AS f
WHERE f.channel_id = 4
  AND f.register_time >= '2025-08-01'
  AND f.register_time < '2025-10-01'
  AND f.paid_within_30d = 1
GROUP BY
    register_month,
    payment_path
ORDER BY
    register_month,
    payment_path;

-- 对比所有渠道8月、9月的首付路径
WITH trial_start AS (
    SELECT
        u.user_id,
        u.register_time,
        u.channel_id,
        MIN(e.event_time) AS first_trial_start_at
    FROM portfolio_growth.users AS u
    LEFT JOIN portfolio_growth.user_events AS e
        ON u.user_id = e.user_id
       AND e.event_type = 'trial_start'
       AND e.event_time >= u.register_time
       AND e.event_time < DATE_ADD(u.register_time, INTERVAL 30 DAY)
    WHERE DATE_ADD(u.register_time, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
    GROUP BY
        u.user_id,
        u.register_time,
        u.channel_id
),
trial_complete AS (
    SELECT
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at,
        MIN(e.event_time) AS first_trial_complete_at
    FROM trial_start AS t
    LEFT JOIN portfolio_growth.user_events AS e
        ON t.user_id = e.user_id
       AND e.event_type = 'trial_complete'
       AND e.event_time > t.first_trial_start_at
       AND e.event_time < DATE_ADD(t.register_time, INTERVAL 30 DAY)
    GROUP BY
        t.user_id,
        t.register_time,
        t.channel_id,
        t.first_trial_start_at
),
first_payment AS (
    SELECT
        user_id,
        MIN(paid_at) AS first_paid_at
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
    GROUP BY user_id
),
user_funnel AS (
	SELECT
	    t.user_id,
	    t.register_time,
	    t.channel_id,
	    t.first_trial_start_at,
	    t.first_trial_complete_at,
	    p.first_paid_at,
	    CASE
	        WHEN p.first_paid_at >= t.register_time
	         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
	        THEN 1
	        ELSE 0
	    END AS paid_within_30d,
	    CASE
	        WHEN p.first_paid_at > t.first_trial_complete_at
	         AND p.first_paid_at < DATE_ADD(t.register_time, INTERVAL 30 DAY)
	        THEN 1
	        ELSE 0
	    END AS funnel_paid_30d
	FROM trial_complete AS t
	LEFT JOIN first_payment AS p
	    ON t.user_id = p.user_id
)
SELECT
    DATE_FORMAT(f.register_time, '%Y-%m') AS register_month,
    c.channel_name,
    COUNT(*) AS eligible_users,

    SUM(f.paid_within_30d) AS all_paid_users_30d,

    SUM(f.funnel_paid_30d) AS complete_then_pay_users,

    SUM(
        CASE
            WHEN f.paid_within_30d = 1
             AND f.first_trial_start_at < f.first_paid_at
             AND f.funnel_paid_30d = 0
            THEN 1
            ELSE 0
        END
    ) AS start_then_pay_before_complete_users,

    SUM(
        CASE
            WHEN f.paid_within_30d = 1
             AND (
                 f.first_trial_start_at IS NULL
                 OR f.first_trial_start_at >= f.first_paid_at
             )
            THEN 1
            ELSE 0
        END
    ) AS pay_without_prior_trial_users

FROM user_funnel AS f
JOIN portfolio_growth.marketing_channels AS c
    ON f.channel_id = c.channel_id
WHERE f.register_time >= '2025-08-01'
  AND f.register_time < '2025-10-01'
GROUP BY
    DATE_FORMAT(f.register_time, '%Y-%m'),
    c.channel_id,
    c.channel_name
ORDER BY c.channel_id, register_month;