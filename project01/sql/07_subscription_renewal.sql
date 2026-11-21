-- 第一步：筛选符合统计条件的到期服务周期
SELECT
    subscription_id,
    user_id,
    order_id,
    plan_code,
    start_at,
    end_at,
    DATE_ADD(end_at, INTERVAL 7 DAY) AS renewal_window_end_at
FROM portfolio_growth.subscriptions
WHERE revoked_at IS NULL
  AND DATE_ADD(end_at, INTERVAL 7 DAY)
      < '2026-01-01 00:00:00'
ORDER BY end_at, subscription_id;
-- 第二步：标记到期周期是否在到期前后7天内续费
WITH eligible_cycles AS (
    SELECT
        subscription_id,
        user_id,
        plan_code,
        start_at,
        end_at
    FROM portfolio_growth.subscriptions
    WHERE revoked_at IS NULL
      AND DATE_ADD(end_at, INTERVAL 7 DAY)
          < '2026-01-01 00:00:00'
)
SELECT
    s.subscription_id,
    s.user_id,
    s.plan_code,
    s.end_at,

    DATE_SUB(s.end_at, INTERVAL 7 DAY) AS renewal_window_start_at,
    DATE_ADD(s.end_at, INTERVAL 7 DAY) AS renewal_window_end_at,

    CASE
        WHEN EXISTS (
            SELECT 1
            FROM portfolio_growth.subscriptions AS n
            JOIN portfolio_growth.orders AS o
                ON n.order_id = o.order_id
               AND n.user_id = o.user_id
            WHERE n.previous_subscription_id = s.subscription_id
              AND n.user_id = s.user_id
              AND o.order_status IN ('paid', 'refunded')
              AND o.paid_at BETWEEN
                  DATE_SUB(s.end_at, INTERVAL 7 DAY)
                  AND DATE_ADD(s.end_at, INTERVAL 7 DAY)
        )
        THEN 1
        ELSE 0
    END AS renewed_within_window

FROM eligible_cycles AS s
ORDER BY s.end_at, s.subscription_id;
-- 第三步：按原周期到期月统计整体续费率
WITH eligible_cycles AS (
    SELECT
        subscription_id,
        user_id,
        end_at
    FROM portfolio_growth.subscriptions
    WHERE revoked_at IS NULL
      AND DATE_ADD(end_at, INTERVAL 7 DAY)
          < '2026-01-01 00:00:00'
),
renewal_flags AS (
    SELECT
        s.subscription_id,
        s.user_id,
        s.end_at,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM portfolio_growth.subscriptions AS n
                JOIN portfolio_growth.orders AS o
                    ON n.order_id = o.order_id
                   AND n.user_id = o.user_id
                WHERE n.previous_subscription_id = s.subscription_id
                  AND n.user_id = s.user_id
                  AND o.order_status IN ('paid', 'refunded')
                  AND o.paid_at BETWEEN
                      DATE_SUB(s.end_at, INTERVAL 7 DAY)
                      AND DATE_ADD(s.end_at, INTERVAL 7 DAY)
            )
            THEN 1
            ELSE 0
        END AS renewed_within_window
    FROM eligible_cycles AS s
)
SELECT
    DATE_FORMAT(end_at, '%Y-%m') AS expiry_month,
    COUNT(*) AS eligible_cycles,
    SUM(renewed_within_window) AS renewed_cycles,
    ROUND(
        SUM(renewed_within_window) / COUNT(*) * 100,
        2
    ) AS renewal_rate_pct
FROM renewal_flags
GROUP BY DATE_FORMAT(end_at, '%Y-%m')
ORDER BY expiry_month;

-- 第四步：按到期月、首次获客渠道统计续费
WITH eligible_cycles AS (
    SELECT
        subscription_id,
        user_id,
        end_at
    FROM portfolio_growth.subscriptions
    WHERE revoked_at IS NULL
      AND DATE_ADD(end_at, INTERVAL 7 DAY)
          < '2026-01-01 00:00:00'
),
renewal_flags AS (
    SELECT
        s.subscription_id,
        s.user_id,
        s.end_at,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM portfolio_growth.subscriptions AS n
                JOIN portfolio_growth.orders AS o
                    ON n.order_id = o.order_id
                   AND n.user_id = o.user_id
                WHERE n.previous_subscription_id = s.subscription_id
                  AND n.user_id = s.user_id
                  AND o.order_status IN ('paid', 'refunded')
                  AND o.paid_at BETWEEN
                      DATE_SUB(s.end_at, INTERVAL 7 DAY)
                      AND DATE_ADD(s.end_at, INTERVAL 7 DAY)
            )
            THEN 1
            ELSE 0
        END AS renewed_within_window
    FROM eligible_cycles AS s
)
SELECT
    DATE_FORMAT(r.end_at, '%Y-%m') AS expiry_month,
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_cycles,
    SUM(r.renewed_within_window) AS renewed_cycles,
    ROUND(
        SUM(r.renewed_within_window) / COUNT(*) * 100,
        2
    ) AS renewal_rate_pct
FROM renewal_flags AS r
JOIN portfolio_growth.users AS u
    ON r.user_id = u.user_id
JOIN portfolio_growth.marketing_channels AS c
    ON u.channel_id = c.channel_id
GROUP BY
    DATE_FORMAT(r.end_at, '%Y-%m'),
    c.channel_id,
    c.channel_name
ORDER BY expiry_month, c.channel_id;
-- 第五步：按原套餐拆分两个渠道10月、11月的续费表现
WITH eligible_cycles AS (
    SELECT
        subscription_id,
        user_id,
        plan_code,
        end_at
    FROM portfolio_growth.subscriptions
    WHERE revoked_at IS NULL
      AND DATE_ADD(end_at, INTERVAL 7 DAY)
          < '2026-01-01 00:00:00'
),
renewal_flags AS (
    SELECT
        s.subscription_id,
        s.user_id,
        s.plan_code,
        s.end_at,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM portfolio_growth.subscriptions AS n
                JOIN portfolio_growth.orders AS o
                    ON n.order_id = o.order_id
                   AND n.user_id = o.user_id
                WHERE n.previous_subscription_id = s.subscription_id
                  AND n.user_id = s.user_id
                  AND o.order_status IN ('paid', 'refunded')
                  AND o.paid_at BETWEEN
                      DATE_SUB(s.end_at, INTERVAL 7 DAY)
                      AND DATE_ADD(s.end_at, INTERVAL 7 DAY)
            )
            THEN 1
            ELSE 0
        END AS renewed_within_window
    FROM eligible_cycles AS s
),
plan_summary AS (
    SELECT
        DATE_FORMAT(r.end_at, '%Y-%m') AS expiry_month,
        c.channel_name,
        r.plan_code,
        COUNT(*) AS eligible_cycles,
        SUM(r.renewed_within_window) AS renewed_cycles
    FROM renewal_flags AS r
    JOIN portfolio_growth.users AS u
        ON r.user_id = u.user_id
    JOIN portfolio_growth.marketing_channels AS c
        ON u.channel_id = c.channel_id
    WHERE u.channel_id IN (1, 5)
      AND r.end_at >= '2025-10-01'
      AND r.end_at < '2025-12-01'
    GROUP BY
        DATE_FORMAT(r.end_at, '%Y-%m'),
        c.channel_name,
        r.plan_code
)
SELECT
    expiry_month,
    channel_name,
    plan_code,
    eligible_cycles,
    renewed_cycles,
    ROUND(
        eligible_cycles
        / SUM(eligible_cycles) OVER (
            PARTITION BY expiry_month, channel_name
        ) * 100,
        2
    ) AS plan_share_pct,
    ROUND(
        renewed_cycles / eligible_cycles * 100,
        2
    ) AS renewal_rate_pct
FROM plan_summary
ORDER BY channel_name, plan_code, expiry_month;
-- 第六步：计算续费窗口开始前7天的活跃天数
WITH eligible_cycles AS (
    SELECT
        s.subscription_id,
        s.user_id,
        s.plan_code,
        s.end_at,
        c.channel_name
    FROM portfolio_growth.subscriptions AS s
    JOIN portfolio_growth.users AS u
        ON s.user_id = u.user_id
    JOIN portfolio_growth.marketing_channels AS c
        ON u.channel_id = c.channel_id
    WHERE s.revoked_at IS NULL
      AND DATE_ADD(s.end_at, INTERVAL 7 DAY)
          < '2026-01-01 00:00:00'
      AND s.end_at >= '2025-10-01'
      AND s.end_at < '2025-12-01'
      AND u.channel_id IN (1, 5)
)
SELECT
    s.subscription_id,
    s.user_id,
    s.channel_name,
    s.plan_code,
    s.end_at,
    DATE_SUB(s.end_at, INTERVAL 14 DAY) AS activity_window_start,
    DATE_SUB(s.end_at, INTERVAL 7 DAY) AS activity_window_end,
    COUNT(DISTINCT DATE(e.event_time)) AS active_days
FROM eligible_cycles AS s
LEFT JOIN portfolio_growth.user_events AS e
    ON s.user_id = e.user_id
   AND e.event_type <> 'register'
   AND e.event_time >= DATE_SUB(s.end_at, INTERVAL 14 DAY)
   AND e.event_time < DATE_SUB(s.end_at, INTERVAL 7 DAY)
GROUP BY
    s.subscription_id,
    s.user_id,
    s.channel_name,
    s.plan_code,
    s.end_at
ORDER BY s.channel_name, s.end_at, s.subscription_id;
-- 第七步：按到期前活跃程度比较续费表现
WITH eligible_cycles AS (
    SELECT
        s.subscription_id,
        s.user_id,
        s.end_at,
        c.channel_name
    FROM portfolio_growth.subscriptions AS s
    JOIN portfolio_growth.users AS u
        ON s.user_id = u.user_id
    JOIN portfolio_growth.marketing_channels AS c
        ON u.channel_id = c.channel_id
    WHERE s.revoked_at IS NULL
      AND DATE_ADD(s.end_at, INTERVAL 7 DAY)
          < '2026-01-01 00:00:00'
      AND s.end_at >= '2025-10-01'
      AND s.end_at < '2025-12-01'
      AND u.channel_id IN (1, 5)
),
cycle_activity AS (
    SELECT
        s.subscription_id,
        s.user_id,
        s.end_at,
        s.channel_name,
        COUNT(DISTINCT DATE(e.event_time)) AS active_days
    FROM eligible_cycles AS s
    LEFT JOIN portfolio_growth.user_events AS e
        ON s.user_id = e.user_id
       AND e.event_type <> 'register'
       AND e.event_time >= DATE_SUB(s.end_at, INTERVAL 14 DAY)
       AND e.event_time < DATE_SUB(s.end_at, INTERVAL 7 DAY)
    GROUP BY
        s.subscription_id,
        s.user_id,
        s.end_at,
        s.channel_name
),
cycle_flags AS (
    SELECT
        a.*,
        CASE
            WHEN a.active_days = 0 THEN '0天'
            WHEN a.active_days <= 2 THEN '1-2天'
            ELSE '3天及以上'
        END AS activity_group,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM portfolio_growth.subscriptions AS n
                JOIN portfolio_growth.orders AS o
                    ON n.order_id = o.order_id
                   AND n.user_id = o.user_id
                WHERE n.previous_subscription_id = a.subscription_id
                  AND n.user_id = a.user_id
                  AND o.order_status IN ('paid', 'refunded')
                  AND o.paid_at BETWEEN
                      DATE_SUB(a.end_at, INTERVAL 7 DAY)
                      AND DATE_ADD(a.end_at, INTERVAL 7 DAY)
            )
            THEN 1
            ELSE 0
        END AS renewed_within_window
    FROM cycle_activity AS a
),
activity_summary AS (
    SELECT
        DATE_FORMAT(end_at, '%Y-%m') AS expiry_month,
        channel_name,
        activity_group,
        COUNT(*) AS eligible_cycles,
        SUM(renewed_within_window) AS renewed_cycles
    FROM cycle_flags
    GROUP BY
        DATE_FORMAT(end_at, '%Y-%m'),
        channel_name,
        activity_group
)
SELECT
    expiry_month,
    channel_name,
    activity_group,
    eligible_cycles,
    renewed_cycles,
    ROUND(
        eligible_cycles
        / SUM(eligible_cycles) OVER (
            PARTITION BY expiry_month, channel_name
        ) * 100,
        2
    ) AS group_share_pct,
    ROUND(
        renewed_cycles / eligible_cycles * 100,
        2
    ) AS renewal_rate_pct
FROM activity_summary
ORDER BY channel_name, activity_group, expiry_month;