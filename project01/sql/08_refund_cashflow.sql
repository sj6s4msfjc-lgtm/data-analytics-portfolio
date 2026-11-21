-- 项目一：退款与净收款
-- 第一步：找到每个用户的首次成功付款订单

WITH paid_orders_ranked AS (
    SELECT
        order_id,
        user_id,
        paid_at,
        order_status,
        paid_amount,
        refund_amount,
        refund_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY paid_at, order_id
        ) AS payment_rank
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
)
SELECT
    order_id,
    user_id,
    paid_at,
    order_status,
    paid_amount,
    refund_amount,
    refund_at
FROM paid_orders_ranked
WHERE payment_rank = 1
ORDER BY user_id;
-- 第二步：按渠道统计首付订单的30日退款率
WITH paid_orders_ranked AS (
    SELECT
        order_id,
        user_id,
        paid_at,
        paid_amount,
        refund_amount,
        refund_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY paid_at, order_id
        ) AS payment_rank
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
),
first_payment_flags AS (
    SELECT
        order_id,
        user_id,
        paid_at,
        paid_amount,
        refund_amount,
        CASE
            WHEN refund_at >= paid_at
             AND refund_at < DATE_ADD(paid_at, INTERVAL 30 DAY)
             AND refund_amount > 0
            THEN 1
            ELSE 0
        END AS refunded_within_30d
    FROM paid_orders_ranked
    WHERE payment_rank = 1
      AND DATE_ADD(paid_at, INTERVAL 30 DAY)
          <= '2026-01-01 00:00:00'
)
SELECT
    c.channel_id,
    c.channel_name,
    COUNT(*) AS eligible_first_orders,
    SUM(f.refunded_within_30d) AS refunded_first_orders_30d,

    ROUND(
        SUM(f.refunded_within_30d) / COUNT(*) * 100,
        2
    ) AS first_order_refund_rate_30d_pct,

    ROUND(SUM(f.paid_amount), 2) AS first_order_paid_amount,

    ROUND(
        SUM(
            CASE
                WHEN f.refunded_within_30d = 1
                THEN f.refund_amount
                ELSE 0
            END
        ),
        2
    ) AS first_order_refund_amount_30d

FROM first_payment_flags AS f
JOIN portfolio_growth.users AS u
    ON f.user_id = u.user_id
JOIN portfolio_growth.marketing_channels AS c
    ON u.channel_id = c.channel_id
GROUP BY
    c.channel_id,
    c.channel_name
ORDER BY c.channel_id;
-- 第三步：按收付款实际发生月统计净收款
WITH cash_movements AS (
    -- 成功付款，按付款月份归属
    SELECT
        DATE_FORMAT(paid_at, '%Y-%m') AS cash_month,
        paid_amount AS received_amount,
        0 AS refunded_amount
    FROM portfolio_growth.orders
    WHERE order_status IN ('paid', 'refunded')
      AND paid_at >= '2025-01-01'
      AND paid_at < '2026-01-01'

    UNION ALL

    -- 退款，按退款月份归属
    SELECT
        DATE_FORMAT(refund_at, '%Y-%m') AS cash_month,
        0 AS received_amount,
        refund_amount AS refunded_amount
    FROM portfolio_growth.orders
    WHERE refund_amount > 0
      AND refund_at >= '2025-01-01'
      AND refund_at < '2026-01-01'
)
SELECT
    cash_month,
    ROUND(SUM(received_amount), 2) AS received_amount,
    ROUND(SUM(refunded_amount), 2) AS refunded_amount,
    ROUND(
        SUM(received_amount) - SUM(refunded_amount),
        2
    ) AS net_cash_received
FROM cash_movements
GROUP BY cash_month
ORDER BY cash_month;