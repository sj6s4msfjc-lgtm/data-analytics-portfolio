CREATE TABLE marketing_channels (
    channel_id INT PRIMARY KEY,
    channel_name VARCHAR(30) NOT NULL UNIQUE,
    channel_type VARCHAR(12) NOT NULL
);

CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,
    register_time DATETIME NOT NULL,
    channel_id INT NOT NULL,
    age_group VARCHAR(12),
    city_tier VARCHAR(20),
    FOREIGN KEY (channel_id) REFERENCES marketing_channels(channel_id)
);

CREATE TABLE user_events (
    event_id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    event_time DATETIME NOT NULL,
    event_type VARCHAR(24) NOT NULL,
    device VARCHAR(12),
    session_id VARCHAR(24) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE orders (
    order_id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    created_at DATETIME NOT NULL,
    paid_at DATETIME,
    order_status VARCHAR(12) NOT NULL,
    list_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) NOT NULL,
    refund_amount DECIMAL(10,2) NOT NULL,
    refund_at DATETIME,
    UNIQUE (order_id, user_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE subscriptions (
    subscription_id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL UNIQUE,
    previous_subscription_id BIGINT UNIQUE,
    plan_code VARCHAR(8) NOT NULL,
    start_at DATETIME NOT NULL,
    end_at DATETIME NOT NULL,
    revoked_at DATETIME,
    UNIQUE (subscription_id, user_id),
    FOREIGN KEY (order_id, user_id) REFERENCES orders(order_id, user_id),
    FOREIGN KEY (previous_subscription_id, user_id) REFERENCES subscriptions(subscription_id, user_id)
);

CREATE INDEX idx_users_register ON users(register_time);
CREATE INDEX idx_events_user_time ON user_events(user_id, event_time);
CREATE INDEX idx_orders_user_paid ON orders(user_id, paid_at);
CREATE INDEX idx_subscriptions_end ON subscriptions(end_at);

