"""Generate the CSV source tables using Python 3 standard library."""
import csv
import random
from contextlib import ExitStack
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "data"
START = datetime(2025, 1, 1)
END = datetime(2026, 1, 1)
CHANNELS = [
    (1, "organic_search", "organic"),
    (2, "referral", "organic"),
    (3, "search_ads", "paid"),
    (4, "social_ads", "paid"),
    (5, "creator", "partner"),
    (6, "unknown", "unknown"),
]
HEADERS = {
    "marketing_channels": "channel_id,channel_name,channel_type",
    "users": "user_id,register_time,channel_id,age_group,city_tier",
    "user_events": "event_id,user_id,event_time,event_type,device,session_id",
    "orders": "order_id,user_id,created_at,paid_at,order_status,list_amount,discount_amount,paid_amount,refund_amount,refund_at",
    "subscriptions": "subscription_id,user_id,order_id,previous_subscription_id,plan_code,start_at,end_at,revoked_at",
}
RNG = random.Random(20251117)
DAY = timedelta(days=1)


def generate():
    ROOT.mkdir(exist_ok=True)
    event_id = order_id = subscription_id = 0
    with ExitStack() as files:
        writers = {}
        for name, fields in HEADERS.items():
            parts = range(1, 5) if name == "user_events" else [0]
            for part in parts:
                stem = f"{name}_{part:02}" if part else name
                stream = files.enter_context((ROOT / f"{stem}.csv").open("w", encoding="utf-8", newline=""))
                writer = csv.writer(stream, lineterminator="\n")
                writer.writerow(fields.split(","))
                writers[stem] = writer.writerow

        for channel in CHANNELS:
            writers["marketing_channels"](channel)
        registration_offsets = sorted(
            RNG.randrange(365 * 86400) for _ in range(50_000)
        )
        for user_id, offset in enumerate(registration_offsets, 1):
            registered = START + timedelta(seconds=offset)
            month = registered.month
            weights = [24, 15, 21, 23, 14, 3] if month < 9 else [17, 9, 16, 43, 12, 3]
            channel = RNG.choices(range(1, 7), weights)[0]
            age = RNG.choices(["18-24", "25-34", "35-44", "45+", ""], [26, 39, 21, 9, 5])[0]
            city = RNG.choices(["tier_1", "new_tier_1", "tier_2", "tier_3_plus", ""], [20, 23, 27, 26, 4])[0]
            writers["users"]((user_id, registered, channel, age, city))
            event_writer = writers[f"user_events_{(user_id - 1) // 12500 + 1:02}"]
            device = RNG.choices(["ios", "android", "web", ""], [28, 48, 23, 1])[0]
            motivation = RNG.betavariate(2, 2.5)
            trial_probability = [.75, .84, .72, .57, .69, .55][channel - 1]
            trial = registered + timedelta(minutes=RNG.randint(10, 9 * 1440))
            if trial >= END or RNG.random() >= trial_probability:
                trial = None
            completed = trial + timedelta(minutes=RNG.randint(15, 1800)) if trial and RNG.random() < .47 + .38 * motivation else None
            events = [(registered, "register", 0)]
            if trial:
                events.extend([(trial, "trial_start", 1), (trial, "lesson_view", 1)])
            if completed and completed < END:
                events.append((completed, "trial_complete", 2))

            def save_order(created, paid, status, price, refund=None, discount=0):
                nonlocal order_id
                order_id += 1
                amount = price - discount if paid else 0
                writers["orders"]((order_id, user_id, created, paid, status, price, discount, amount, amount if refund else 0, refund))
                return order_id

            if RNG.random() < .07:
                created = registered + timedelta(minutes=RNG.randint(1, 10080))
                if created < END:
                    save_order(created, None, RNG.choice(["failed", "cancelled"]), 99)

            baseline = [.23, .30, .22, .13, .19, .12][channel - 1]
            purchase_chance = baseline * (.48 + motivation) + (.10 if completed else 0)
            if not trial:
                purchase_chance *= .16
            elif not completed:
                purchase_chance *= .58
            earliest = completed or trial or registered
            paid = earliest + timedelta(minutes=RNG.randint(30, 15 * 1440))
            service_windows = []
            if paid < END and RNG.random() < purchase_chance:
                duration = RNG.choices([30, 90], [79, 21])[0]
                price = 99 if duration == 30 else 249
                previous = None
                start = paid
                for cycle in range(16):
                    end = start + duration * DAY
                    refund = start + timedelta(hours=RNG.randint(3, 110)) if RNG.random() < (.043 if cycle == 0 else .016) else None
                    if refund and refund >= END:
                        refund = None
                    discount = RNG.choice([10, 20, 30]) if RNG.random() < (.40 if cycle == 0 else .14) else 0
                    paid_order = save_order(paid - timedelta(minutes=5), paid, "refunded" if refund else "paid", price, refund, discount)
                    subscription_id += 1
                    writers["subscriptions"]((subscription_id, user_id, paid_order, previous, f"D{duration}", start, end, refund))
                    service_windows.append((start, refund or end))
                    if refund:
                        break
                    renew_probability = [.65, .73, .61, .45, .55, .44][channel - 1] + .23 * (motivation - .45)
                    if channel == 4 and 9 <= end.month <= 11:
                        renew_probability -= .095
                    if RNG.random() >= renew_probability:
                        break
                    paid = end + timedelta(hours=RNG.randint(-144, 168))
                    start = max(paid, end)
                    if paid >= END:
                        break
                    previous = subscription_id

            active_days = 7 + round(38 * motivation) + (10 if trial else 0)
            sessions = int(RNG.gammavariate(2.15, 4.7) * (.55 + motivation) + (3 if trial else 0))
            for session in range(3, sessions + 3):
                visits = registered + timedelta(minutes=RNG.randint(1, 1440 * active_days))
                events.append((visits, "app_open", session))
                if RNG.random() < .76:
                    events.append((visits + timedelta(seconds=20), "browse_catalog", session))
                if RNG.random() < .34:
                    events.append((visits + timedelta(seconds=55), "lesson_preview", session))
            for session, (start, stop) in enumerate(service_windows, sessions + 3):
                if start >= stop or start >= END:
                    continue
                for visit in range(RNG.randint(2, 12)):
                    seconds = RNG.randrange(int((stop - start).total_seconds()))
                    events.append((start + timedelta(seconds=seconds), "paid_lesson_view", session * 100 + visit))
            for when, kind, session in sorted(events):
                if when < END:
                    event_id += 1
                    event_writer((event_id, user_id, when, kind, device, f"{user_id}-{session}"))
    print(f"Users: 50000, events: {event_id}, orders: {order_id}, subscriptions: {subscription_id}")


if __name__ == "__main__":
    generate()
