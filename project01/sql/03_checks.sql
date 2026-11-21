SELECT 'marketing_channels' AS table_name, COUNT(*) AS row_count, 6 AS expected FROM marketing_channels
UNION ALL SELECT 'users', COUNT(*), 50000 FROM users
UNION ALL SELECT 'user_events', COUNT(*), 1420694 FROM user_events
UNION ALL SELECT 'orders', COUNT(*), 20744 FROM orders
UNION ALL SELECT 'subscriptions', COUNT(*), 17269 FROM subscriptions;

-- Each issue count must be zero.
SELECT 'event_time_or_user' AS check_name, COUNT(*) AS issues
FROM user_events e LEFT JOIN users u ON e.user_id = u.user_id
WHERE u.user_id IS NULL OR e.event_time < u.register_time OR e.event_time >= '2026-01-01'
UNION ALL
SELECT 'register_event', COUNT(*)
FROM users u LEFT JOIN (
    SELECT user_id, COUNT(*) AS n, MIN(event_time) AS register_event_at
    FROM user_events WHERE event_type = 'register' GROUP BY user_id
) e ON e.user_id = u.user_id
WHERE e.n IS NULL OR e.n <> 1 OR e.register_event_at <> u.register_time
UNION ALL
SELECT 'order_time_or_amount', COUNT(*)
FROM orders o LEFT JOIN users u ON o.user_id = u.user_id
WHERE u.user_id IS NULL OR o.created_at < u.register_time OR o.created_at >= '2026-01-01'
   OR o.order_status NOT IN ('paid', 'refunded', 'failed', 'cancelled')
   OR (o.order_status IN ('paid', 'refunded') AND
        (o.paid_at IS NULL OR o.paid_at < o.created_at OR o.paid_at >= '2026-01-01'
         OR o.paid_amount <= 0 OR o.paid_amount <> o.list_amount - o.discount_amount))
   OR (o.order_status IN ('failed', 'cancelled') AND (o.paid_at IS NOT NULL OR o.paid_amount <> 0))
   OR (o.order_status = 'refunded' AND
        (o.refund_at IS NULL OR o.refund_at <= o.paid_at OR o.refund_at >= '2026-01-01'
         OR o.refund_amount <> o.paid_amount))
   OR (o.order_status <> 'refunded' AND (o.refund_at IS NOT NULL OR o.refund_amount <> 0))
UNION ALL
SELECT 'subscription_to_order', COUNT(*)
FROM subscriptions s LEFT JOIN orders o ON s.order_id = o.order_id AND s.user_id = o.user_id
WHERE o.paid_at IS NULL OR o.paid_at > s.start_at OR s.end_at <= s.start_at
   OR (s.revoked_at IS NOT NULL AND (s.revoked_at < s.start_at OR s.revoked_at >= s.end_at))
   OR COALESCE(s.revoked_at, '2026-01-01') <> COALESCE(o.refund_at, '2026-01-01')
UNION ALL
SELECT 'paid_order_without_subscription', COUNT(*)
FROM orders o LEFT JOIN subscriptions s ON o.order_id = s.order_id
WHERE o.paid_at IS NOT NULL AND s.subscription_id IS NULL
UNION ALL
SELECT 'subscription_chain', COUNT(*)
FROM subscriptions s LEFT JOIN subscriptions p ON s.previous_subscription_id = p.subscription_id
WHERE s.previous_subscription_id IS NOT NULL
  AND (p.subscription_id IS NULL OR p.user_id <> s.user_id OR p.revoked_at IS NOT NULL
       OR s.start_at < p.end_at OR s.subscription_id <= p.subscription_id)
UNION ALL
SELECT 'trial_complete_without_start', COUNT(*)
FROM user_events e
WHERE e.event_type = 'trial_complete'
  AND NOT EXISTS (
    SELECT 1 FROM user_events t
    WHERE t.user_id = e.user_id AND t.event_type = 'trial_start' AND t.event_time < e.event_time
  )
UNION ALL
SELECT 'paid_view_outside_service', COUNT(*)
FROM user_events e
WHERE e.event_type = 'paid_lesson_view'
  AND NOT EXISTS (
    SELECT 1 FROM subscriptions s
    WHERE s.user_id = e.user_id AND e.event_time >= s.start_at
      AND e.event_time < COALESCE(s.revoked_at, s.end_at)
  );
