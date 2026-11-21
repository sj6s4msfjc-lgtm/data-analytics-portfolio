## 分析成果入口

- [PDF完整报告](report/project01_analysis_report.pdf)
- [Markdown分析报告](report/analysis_report.md)
- [Excel核心指标看板](excel/07_project_dashboard.xlsx)
- 详细分析工作簿位于 `excel/`，计算过程位于 `sql/`，原始合成数据位于 `data/`。

全部数据为模拟数据，策略与实验方案尚未实际实施。

# 项目一｜线上知识付费平台用户增长与留存

2025-01-01 至 2025-12-31，共 12 个月，时间统一按北京时间理解。观测截止为 2026-01-01 00:00:00（不含）。所有记录均为合成数据，用于个人数据分析作品集。订阅周期起止日期可能跨过观测截止，因为它们是购买时就已确定的服务日期。

## 表关系与数据量

| 表 | 每一行代表 | 主键 | 关联 | 数据行数 |
|---|---|---|---|---:|
| marketing_channels | 一个首次获客渠道 | channel_id | 一个渠道可对应多个用户 | 6 |
| users | 一个注册账号 | user_id | channel_id → marketing_channels | 50,000 |
| user_events | 一次行为事件 | event_id | user_id → users | 1,420,694 |
| orders | 一笔订单，含未支付订单 | order_id | user_id → users | 20,744 |
| subscriptions | 一个付费服务周期，含后续撤销周期 | subscription_id | order_id + user_id → orders；previous_subscription_id → 同用户上一周期 | 17,269 |

每一笔成功支付的订单对应一个周期。一位用户可以有多笔订单、多个服务周期以及多条事件。行为和订单同时按 user_id 连接会放大行数，例如三条事件与两笔订单会产生六行。按用户做漏斗时，先将每类事件与首付归并到用户粒度。

四个 user_events_*.csv 只是同一张表的分片，按 user_id 分段。每片数据行数依次为 382,228、380,277、366,991、291,198。各文件是 UTF-8 CSV，空字段代表缺失或业务上不适用，导入后为 NULL。unknown 则是渠道系统里的一个明确分类。

## MySQL 8 导入

在本机 MySQL 中创建一个空库，然后在解压后的 project01 目录执行以下命令。连接参数按自己的环境调整。脚本使用 LOAD DATA LOCAL INFILE，需服务器允许 local_infile，客户端使用 --local-infile=1。导入完成后核对所有行数，第二个结果集的异常计数都应为 0。

```bash
mysql -u your_user -p -e "CREATE DATABASE portfolio_growth CHARACTER SET utf8mb4"
mysql -u your_user -p portfolio_growth < sql/01_schema.sql
mysql --local-infile=1 -u your_user -p portfolio_growth < sql/02_load.sql
mysql -u your_user -p portfolio_growth < sql/03_checks.sql
```

请在空库中执行首次导入。若导入中断，使用另一个空库重跑三份脚本并校验结果。generate.py 使用 Python 3 标准库和固定种子，可重新生成 CSV，运行时会覆盖 data 目录中对应的八个文件。

## Excel 使用

注册、渠道、订单、订阅表可分别通过「数据 → 自文本/CSV」导入。事件表可按分片查看。完整事件表合计 142 万多行，超过 Excel 单张工作表的行数容量。做全量报表时，先用 MySQL 聚合导出，再把结果导入 Excel 做透视表和图表。导入时选 UTF-8，时间列按日期时间识别，session_id 按文本导入。

## 字段字典

### marketing_channels

| 字段 | 含义 |
|---|---|
| channel_id | 渠道 ID |
| channel_name | organic_search 自然搜索、referral 推荐、search_ads 搜索广告、social_ads 社交广告、creator 创作者合作、unknown 来源未知 |
| channel_type | organic 自然、paid 付费、partner 合作、unknown 未知 |

### users

| 字段 | 含义 |
|---|---|
| user_id | 用户 ID |
| register_time | 注册时间 |
| channel_id | 注册时记录的首次获客来源 |
| age_group | 年龄分组，可缺失 |
| city_tier | 城市分级，可缺失。tier_1 一线、new_tier_1 新一线、tier_2 二线、tier_3_plus 三线及以下 |

### user_events

| 字段 | 含义 |
|---|---|
| event_id | 事件唯一 ID |
| user_id | 行为所属用户 |
| event_time | 行为发生时间 |
| event_type | register 注册、trial_start 开始试听、lesson_view 试听播放、trial_complete 完成试听、app_open 打开平台、browse_catalog 浏览目录、lesson_preview 试看内容、paid_lesson_view 观看付费内容 |
| device | 设备 ios / android / web，可缺失 |
| session_id | 会话 ID。同一会话可记录多个事件 |

### orders

| 字段 | 含义 |
|---|---|
| order_id | 订单 ID |
| user_id | 下单用户 |
| created_at | 订单创建时间 |
| paid_at | 成功支付时间，支付失败或取消时为空 |
| order_status | 截至观测期末状态。paid 已支付、refunded 已全额退款、failed 支付失败、cancelled 已取消 |
| list_amount | 下单商品原价，单位元 |
| discount_amount | 优惠金额，单位元 |
| paid_amount | 实收金额，退款后仍保留原支付金额 |
| refund_amount | 已退金额，当前数据只有全额退款 |
| refund_at | 退款发生时间，未退款时为空 |

### subscriptions

| 字段 | 含义 |
|---|---|
| subscription_id | 服务周期 ID |
| user_id | 使用服务的用户 |
| order_id | 产生此周期的已付款订单 |
| previous_subscription_id | 续费对应的上一服务周期，首购周期为空 |
| plan_code | D30 为 30 天、D90 为 90 天 |
| start_at | 服务生效时间。提前续费时从上一周期到期时开始 |
| end_at | 原定到期时间，周期采用左闭右开区间 |
| revoked_at | 退款导致服务撤销的时间，未撤销时为空 |

## 首轮分析口径

| 问题 | 建议口径 |
|---|---|
| 哪个渠道拉来的用户更容易付费？ | 按注册月和首次获客渠道，比较注册后 30 日内发生过首次成功支付的用户占比。分母只用已满 30 日观察窗的用户。支付后退款的用户仍计作曾付费，另看退款率。 |
| 哪里掉得最多？ | 比较注册 → 开始试听 → 完成试听 → 支付的顺序漏斗。每一步按用户去重并验证时序。有些用户会跳过试听直接付费，同时报告整体首付率和试听路径漏斗。 |
| 哪些用户继续活跃？ | 按注册月做队列，D7 定义为注册日后的第 7 个自然日出现至少一次非注册事件。D30 同理。未观察满对应自然日的用户不进分母。 |
| 到期后有多少人续费？ | 以服务周期为单位，按原到期月分组。排除已撤销的原周期和到期后 7 天尚未观察完整的周期。检查是否存在一笔相连的成功续费订单，支付时间在到期前 7 天至到期后 7 天内（含边界）。续费后的退款另外统计。 |
| 续费波动发生在哪里？ | 分渠道比较到期周期占比和渠道内续费率，再用基期渠道权重做一次固定结构对比。把统计归因与因果验证分开。 |
| 怎样衡量收款？ | 按 paid_at 汇总收款，按 refund_at 汇总退款，两者按各自发生月计算净收款。 |

数据包含多渠道、人群行为差异、重复访问、缺失属性、跨月续费、支付失败及退款。它模拟单产品会员服务、首次来源归因与连续续费链。第一阶段缺少曝光、点击和投放成本，因此可以比较渠道注册后的质量与净收款，CAC 和投放 ROI 需要后续补充成本数据。
