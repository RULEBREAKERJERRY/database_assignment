# 数据库脚本

数据库版本：MySQL 8.0，字符集 `utf8mb4`。

首次初始化按文件名前缀依次执行：

| 顺序 | 脚本 | 作用 | 依赖 |
|---|---|---|---|
| 1 | `01_schema.sql` | 建库、12 张表、主外键与 `CHECK` | — |
| 2 | `02_indexes.sql` | 17 个二级索引，按列数判重后可重复执行 | 01 |
| 3 | `03_views.sql` | 统计视图 `v_video_statistics` | 01 |
| 4 | `04_seed.sql` | 分类、测试账号、可核验样例 | 01 |
| 5 | `05_required_queries.sql` | 必做关联查询与四项综合统计（查询演示） | 04 |
| 6 | `06_transaction_demo.sql` | 事务成功与回滚存储过程（事务演示） | 04 |
| 7 | `07_generate_test_data.sql` | 1 万条行为 + 2000 评论 + 2000 关注 | 04 |
| 8 | `08_performance_test.sql` | 索引对比与 SQL 改写对比 | 07 |
| 9 | `09_scale_experiment.sql` | 递归 CTE 集合插入，扩到 10 万条行为 | 07 |
| 10 | `10_triggers.sql` | 审计表 `video_audit` 与两个 `videos` 触发器 | 01 |
| 11 | `11_concurrency.sql` | 并发实验测试夹具与单会话对照演示 | 01 |
| 12 | `12_advanced_queries.sql` | 窗口函数与递归 CTE 五条查询 | 07 + 09 |

两种执行方式：

```bash
# 只建结构与演示数据（01—06、10、11）
./scripts/init-database.sh

# 连造数与性能/高级查询一起跑（再加 07、08、09、12）
./scripts/init-database.sh --perf
```

手工执行时注意 `10_triggers.sql` 的最后一步会故意抛 `ERROR 1644 (45000)` 来演示「已删除作品不可恢复」，批量执行需要 `--force`，或按上面的脚本方式单独处理：

```bash
mysql -uroot --force < database/10_triggers.sql
```

Docker Compose 首次创建数据卷时会自动执行前四个脚本。修改初始化脚本后，如已有数据卷，应手工执行变更，避免误删已有数据。注意 `01`—`04` 之外的脚本不会被 Compose 自动执行。

## 可重复执行的实现方式

- 建表用 `CREATE TABLE IF NOT EXISTS`；
- 索引用 `rebuild_videos_index` 存储过程，比对 `information_schema.STATISTICS` 的列数后决定是否重建（列定义从 2 列改到 3 列时只判"索引存在"会跳过）；
- 视图用 `CREATE OR REPLACE`；
- 种子数据用 `ON DUPLICATE KEY UPDATE`；
- 造数脚本用 `NOT EXISTS` 与特征串（如 `content LIKE '性能评论内容%'`）判重，重复执行不会翻倍。
