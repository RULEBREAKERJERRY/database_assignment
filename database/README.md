# 数据库脚本

数据库版本：MySQL 8.0，字符集 `utf8mb4`。

首次初始化按文件名前缀依次执行：

1. `01_schema.sql`
2. `02_indexes.sql`
3. `03_views.sql`
4. `04_seed.sql`
5. `05_required_queries.sql`（查询演示）
6. `06_transaction_demo.sql`（事务演示）
7. `07_generate_test_data.sql`（性能数据，按需执行）
8. `08_performance_test.sql`（性能分析）

Docker Compose 首次创建数据卷时会自动执行前四个脚本。修改初始化脚本后，如已有数据卷，应手工执行变更，避免误删已有数据。

