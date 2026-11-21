LOAD DATA LOCAL INFILE 'data/marketing_channels.csv'
INTO TABLE marketing_channels CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(channel_id, channel_name, channel_type);
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/users.csv'
INTO TABLE users CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(user_id, register_time, channel_id, @age_group, @city_tier)
SET age_group = NULLIF(@age_group, ''), city_tier = NULLIF(@city_tier, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/user_events_01.csv'
INTO TABLE user_events CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(event_id, user_id, event_time, event_type, @device, session_id)
SET device = NULLIF(@device, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/user_events_02.csv'
INTO TABLE user_events CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(event_id, user_id, event_time, event_type, @device, session_id)
SET device = NULLIF(@device, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/user_events_03.csv'
INTO TABLE user_events CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(event_id, user_id, event_time, event_type, @device, session_id)
SET device = NULLIF(@device, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/user_events_04.csv'
INTO TABLE user_events CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(event_id, user_id, event_time, event_type, @device, session_id)
SET device = NULLIF(@device, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/orders.csv'
INTO TABLE orders CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, user_id, created_at, @paid_at, order_status, list_amount, discount_amount, paid_amount, refund_amount, @refund_at)
SET paid_at = NULLIF(@paid_at, ''), refund_at = NULLIF(@refund_at, '');
SHOW WARNINGS;

LOAD DATA LOCAL INFILE 'data/subscriptions.csv'
INTO TABLE subscriptions CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(subscription_id, user_id, order_id, @previous_subscription_id, plan_code, start_at, end_at, @revoked_at)
SET previous_subscription_id = NULLIF(@previous_subscription_id, ''), revoked_at = NULLIF(@revoked_at, '');
SHOW WARNINGS;
