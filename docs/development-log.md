# 开发文档

本文记录本项目的三轮开发过程：每轮的目标、具体改动、验证结果与遗留问题。

与课程设计报告的分工：报告（`docs/report/`）讲**设计与实验结果**，本文讲**过程与决策依据**——为什么这么改、改之前错在哪、怎么验证改对了。需要看设计取舍的读者读报告，需要接手或复现的读者读本文。

---

## 1 环境与复现

### 1.1 运行环境

| 组件 | 版本 | 说明 |
|---|---|---|
| MySQL | 8.0.40（InnoDB，`utf8mb4`） | 需要 `CHECK`、`DATETIME(3)`、窗口函数、递归 CTE |
| JDK | 11 | Spring Boot 2.7 是最后支持 Java 11 的主线 |
| Maven | 3.8+ | — |
| Node.js | 18+ | Vite 6 要求 |
| pandoc | 任意较新版本 | 仅生成 Word 报告时需要 |

开发期使用项目内独立部署的 MySQL 实例（数据目录 `.local/mysql-data/`，socket `.local/mysql.sock`，端口 **3307**），与系统已有数据库完全隔离。`.local/` 已加入 `.gitignore`，不随仓库分发；克隆后按 `docker-compose.yml` 起一个 3306 的实例即可，脚本本身不依赖 3307。

### 1.2 复现步骤

```bash
# 1. 数据库：按序执行 01—12
./scripts/init-database.sh          # 结构 + 种子 + 演示（01—06、10、11）
./scripts/init-database.sh --perf   # 追加造数与性能/高级查询（07、08、09、12）

# 2. 后端（默认 8080）
./scripts/start-backend.sh

# 3. 前端（默认 5173）
./scripts/start-frontend.sh

# 4. 验收
./scripts/e2e-acceptance.sh         # 49 项断言
./scripts/concurrency-test.sh       # 5 组两会话锁竞争

# 5. 重新生成报告与插图（可选）
python3 scripts/make_report_figures.py   # 依赖 Pillow
python3 scripts/build_report_docx.py     # 依赖 pandoc + python-docx
```

`10_triggers.sql` 的最后一步会故意抛 `ERROR 1644 (45000)` 来演示"已删除作品不可恢复"。`init-database.sh` 单独放行这一条并校验错误码，手工执行时需加 `--force`。

`init-database.sh` 走 Docker Compose（与 `docker-compose.yml` 一致）。本文档记录的全部实验数据是在项目内的独立实例（端口 3307，`.local/`）上按序手工执行同一批脚本得到的，两条路径执行的脚本完全相同。

---

## 2 三轮开发概览

| 轮次 | 主题 | 主要改动 | 验收指标 |
|---|---|---|---|
| 第一轮 | 基线跑通与报告成型 | 独立 MySQL 环境；修 4 个缺陷；跑通全部实验；产出报告（md + docx） | e2e 32 项断言通过 |
| 第二轮 | 必做功能补齐 | 粉丝/关注列表页、首页作者筛选、行为查询分页、必做查询 bug | e2e 32 → 45 项 |
| 第三轮 | 提高部分 | 触发器与审计、并发实验、列表页性能、窗口函数/递归 CTE、代码层小修 | e2e 45 → 49 项，单测 2 → 6 |

三轮的改动都叠加在同一份代码上，多处文件跨轮修改（如 `07`、`09`、`VideoMapper.xml`、`e2e-acceptance.sh`）。仓库历史按这三轮拆成三个提交，拆分规则是**把文件归入它首次创建或首次修改的那一轮**；跨轮修改的文件不还原中间态，直接携带最终内容（中间草稿未单独保存）。由此可以保证：

- 三个提交都能独立编译，`mvn test` 均通过（第一、二轮各 2 个用例，第三轮 6 个）；
- 三个提交的文件树合起来与完整实现逐字节一致（`git diff` 为空）；
- `07`、`09`、`e2e-acceptance.sh` 出现在第一个提交里，但携带的是最终形态；报告正文在第三个提交定稿。

之所以不逐块还原中间态：`07`、`09` 与报告的改动是整段重写而非局部替换，凭最终结果反推中间版本只能靠猜，那样造出来的"历史"反而不可信。

---

## 3 第一轮：基线跑通与报告成型

### 3.1 目标

仓库里只有建表脚本和一份骨架代码，没有任何实测数据，报告也不存在。这一轮的目标是把"设计"变成"可验证的事实"：真实跑一遍建表、查询、事务、性能，把结果写进报告。

### 3.2 环境隔离

机器上已有其他项目的 MySQL，直接建库会互相影响。因此解压 MySQL 8.0.40 免安装包到 `.local/`，用独立数据目录与 socket 起了一个 3307 的实例，并写了客户端包装器 `.local/bin/my`（自动带上 `--socket` 与 `--default-character-set=utf8mb4`）。这样实验可以随时 `DROP DATABASE` 重来，不会波及任何已有数据。

### 3.3 修复的四个缺陷

跑通的过程中发现四处会直接影响演示的问题。

**（1）种子账号全部无法登录。** README 声明测试账号密码是 `password`，但 `04_seed.sql` 里的 BCrypt 哈希与这个明文不匹配，`admin`、`alice`、`bob` 三个账号全部登录失败。用 bcrypt 库逐个校验确认后重新生成哈希，同步更新 `04`、`07`、`09` 三个脚本。这个缺陷会让现场演示的第一步就失败。

**（2）已删除评论的行为时间取错列。** `05_required_queries.sql` 的行为明细查询里，`COMMENT_DELETED` 类型用的发生时间是 `c.created_at`，导致"删除时间"显示成"发表时间"，与需求里"删除后仍能查到删除时间"不符。改为：

```sql
IF(c.is_deleted, c.deleted_at, c.created_at) AS occurred_at
```

**（3）造数脚本时间分布过窄，某条必做查询恒为空集。** `07` 用 `MOD(i, 30)` 算天数，而同一用户的第 k 条播放记录间隔是 100，`gcd(100, 30) = 10`，于是每个用户的播放只落在 3 个日期上，"近七天至少三天观看过视频的用户"这条查询永远返回空集。改为 `MOD(i * 7 + FLOOR(i / 100), 30)`（步长与 30 互质），30 天全覆盖，查询恢复正常。

**（4）上传接口误拒合法视频。** 原实现只接受 `Content-Type` 以 `video/` 开头的文件，而 curl、部分移动端与采集工具上传 `.mp4` 时会退化为 `application/octet-stream`，被误判为"只能上传视频文件"。修复方式是：类型为 `application/octet-stream` 且扩展名在白名单内时放行，同时保留扩展名白名单与文件名归一化，避免路径穿越。

### 3.4 产出

- `database/08_performance_test.sql` 重写：原本打算用 `DROP INDEX idx_play_user_time` 造"无索引"场景，实际报 `ERROR 1553`（该索引首列承担外键支撑），改为"建单列索引接替 → 删联合索引 → 临时解除外键"的三步法，末尾自动恢复。
- `database/09_scale_experiment.sql` 新增：用递归 CTE 批量插入，把数据从 1 万扩到 10 万。
- `scripts/e2e-acceptance.sh` 新增：按需求文档的验收路径用真实 HTTP 请求走完整流程，32 项断言。
- 报告 `docs/report/短视频数据管理系统-课程设计报告.md` 与 `.docx`，含 4 张插图（架构图、两层 DFD、E-R 图）。

### 3.5 验证

- 12 个脚本（当时是 01—09）从空库开始按序执行，全部无报错。
- 视图统计值与明细直接计数逐视频比对（503 个视频 × 6 项指标），0 处不一致。
- `e2e-acceptance.sh` 32 项断言全通过。
- 报告中的执行时间、扫描行数、cost 全部来自 `EXPLAIN ANALYZE` 原始输出，日志留档在 `docs/report/perf-1w.log`、`perf-10w.log`。

---

## 4 第二轮：必做功能补齐

### 4.1 三个"有接口没入口"

后端能力已经具备，但前端一次都没调用，从使用者角度看等于不存在。

**粉丝列表与关注列表。** `/api/users/{id}/following` 与 `/followers` 早已在 `UserMapper` 里实现。把个人主页改成三个页签（公开作品 / 关注 / 粉丝），切换时按需拉取，用 `loaded` 标记保证同一页签只请求一次。列表展示头像首字母、昵称、`@username`、简介与 `followed_at`，整行可点击跳转。

同时补了关注/取关按钮：调用 `/api/follows/{userId}` 并带 `Idempotency-Key`，关注后**同时**刷新用户统计与已展开的粉丝列表。这一步不能省——粉丝数与粉丝列表会同时变化，只更新其中一个会出现"数字变了、列表没变"的不一致。

**首页按作者筛选。** `/api/videos` 一直支持 `authorId` 参数，但首页没有传。新增 `GET /api/users?keyword=&limit=`（昵称/用户名模糊匹配，按粉丝数降序），前端做远程检索下拉，避免把全量用户一次性灌进浏览器。选中作者后把 `authorId` 写进地址栏（`router.replace`），刷新或分享链接时筛选状态不丢；从别处带 `?authorId=` 进来时，若该作者不在默认 20 条选项里，会单独取一次资料补进下拉，否则下拉框会显示成裸 ID。

**行为查询分页。** 原实现只做 `LIMIT/OFFSET`，前端无法知道总数，也画不出页码。`BehaviorMapper` 增加 `count`，与 `query` 共用同一段 `UNION ALL` 数据源（抽成 `<sql id="behaviorSource">`）和同一组 `<where>` 条件（抽成 `<sql id="behaviorWhere">`），Controller 返回 `PageResult`，前端加 `el-pagination`（可选每页 10/20/50/100）。

把两段 SQL 抽成公共片段不是为了少写几行，而是为了避免"改了一处忘了另一处"导致总数与列表对不上——这是分页最常见的 bug。

### 4.2 一个附带修复

`main.ts` 没有引入 Element Plus 的中文语言包，分页组件显示的是 "Total / Go to"。补上 `zh-cn` 后恢复为"共 N 条 / 前往"。

### 4.3 验证

- `e2e-acceptance.sh` 从 32 项扩到 45 项：新增步骤 3b（粉丝/关注字段）、3c（作者筛选 + 用户检索）、5b（行为分页的总数、每页条数、翻页连续性）。
- 前端 `vue-tsc --noEmit` 与 `vite build` 通过。
- 用 `playwright-core` 驱动系统 Chrome 无头模式验证三个页面：筛选后卡片 12 → 1、URL 带 `?authorId=2`、关注按钮从"关注"变"已关注"且粉丝数 0 → 1。截图存 `docs/report/figures/fig5~fig7`。

---

## 5 第三轮：提高部分

### 5.1 触发器与审计表

`database/10_triggers.sql` 新建 `video_audit` 与两个 `videos` 触发器。

审计表**刻意不建外键**。如果给它加 `FK → videos.id` 并沿用全库的 `RESTRICT`，一条有审计记录的视频就永远无法物理清理，审计日志反而成了业务表的枷锁。审计表只存 `video_id` 的值，不声明引用完整性。

两个触发器分工：`BEFORE UPDATE` 拦截"已删除作品被恢复"（`SIGNAL SQLSTATE '45000'`），`AFTER UPDATE` 在 `NEW.status <> OLD.status` 时写审计。用 `BEFORE` 拦截是因为必须在写入生效前发生，否则要回滚一次已完成的修改；用 `AFTER` 记录是因为要读到 `NEW` 的最终值。

`IF NEW.status <> OLD.status` 这道判断是必要的：改标题、改简介也会触发 `AFTER UPDATE`，不判断就会产生大量 `PUBLISHED→PUBLISHED` 的噪声。端到端脚本专门为此加了一条反向断言——删除之后再改一次标题，断言审计总数仍为 1。

实测五步：删除写 1 条 `PUBLISHED→DELETED`；事务回滚后审计归零；只改标题 0 条；`information_schema.TRIGGERS` 里两个触发器都在；`DELETED→PUBLISHED` 报 `ERROR 1644 (45000)`。

第 2 步是最关键的性质：**触发器不是独立的"后台动作"，它就是事务的一部分**。业务回滚时审计也回滚，因此审计表里不会出现"业务没发生、审计却记了一笔"的幽灵记录。

接口层加了 `GET /api/admin/videos/{id}/audit`，仅 `ADMIN` 可访问。

### 5.2 并发实验

`scripts/concurrency-test.sh` 用两个独立 `mysql` 会话跑 5 组用例，会话 A 先取锁并 `SLEEP(2)`，会话 B 在 0.4 s 后发起竞争。

| 用例 | 会话 A | 会话 B | B 的锁等待 | `data_lock_waits` | B 读到的结果 |
|---|---|---|---|---|---|
| 1 | `FOR UPDATE` | `FOR UPDATE` | 1592 ms | 1 | — |
| 2 | `FOR SHARE` | `FOR SHARE` | **0 ms** | 0 | — |
| 3 | `UPDATE ... DELETED` | `FOR SHARE` | 1579 ms | 1 | `DELETED` |
| 4 | `FOR SHARE` | `UPDATE ... DELETED` | 1576 ms | 1 | — |
| 5 | `UPDATE ... DELETED` | 普通 `SELECT` | **0 ms** | 0 | `PUBLISHED` |

用例 5 是对照组，也是理解前四组的前提：`REPEATABLE-READ` 下的普通 `SELECT` 是快照读、不加锁，所以"先读状态再判断"的写法在并发下不安全，必须显式加锁。

另外 `database/11_concurrency.sql` 有一组单会话对照：直接向一条 `DELETED` 视频插入点赞，`video_likes` 会插入成功。这说明**数据库本身挡不住"给已删除视频点赞"**——外键指向 `videos.id`，行还在，只是 `status` 变了，插入不违反任何约束。这条规则只能由应用层的锁保证。

### 5.3 列表页性能

首页列表原本直接 `JOIN v_video_statistics`，只取 12 行却要先算完全部聚合。这一轮从两个互相独立的方向同时下手：

**查询改写。** 视图对每张子表做全量 `GROUP BY`，`JOIN` 时优化器会把"全部视频的聚合结果"物化成临时表再丢弃到只剩 12 行。改成按 `video_id` 的相关子查询后，外层先用索引拿到 12 行，子查询 `loops=12`，每行只是 6 次覆盖索引查找。`list` 与 `detail` 共用同一段 `<sql id="videoColumns">`，改一处同时生效。

**索引补列。** 列表排序是 `ORDER BY published_at DESC, id DESC`，原索引只到 `published_at`，优化器必须 filesort 才能定序。给三个 `videos` 联合索引补上 `id DESC` 尾部列后，`Sort` 节点直接从执行计划里消失（排序开销 3.96 ms → 0.04 ms）。

10 万规模实测：

| 变体 | 查询 | 耗时 |
|---|---|---|
| A | `JOIN v_video_statistics` 取 12 行 | 33.6 ms |
| B | 相关子查询取 12 行 | **0.026 ms** |
| C | 详情页：视图取单行 | **31.8 ms** |

C 这一行是最有说服力的发现：详情页只显示一个视频，视图却要 31.8 ms——它仍然把全库 5501 个视频的聚合算了一遍。开销与"要看几条"无关，只与"库里有多少视频"有关。因此改写不能只用在列表页。

两条经验：**查询改写消除的是"扫描量"，索引补列消除的是"排序量"，两者不能互相替代**。只改写 SQL 会把 filesort 留在计划里；只补索引则挡不住全量聚合。P0 阶段只做改写时 10 万规模是 1.86 ms，补上索引后才到 0.020 ms。

改造索引时又撞了一次 `ERROR 1553`：`idx_videos_author_time` 的首列 `author_id`、`idx_videos_category_time` 的首列 `category_id` 都是外键的支撑列，不能直接 `DROP`。`02_indexes.sql` 因此重写为 `rebuild_videos_index` 存储过程：先建单列临时索引接替外键职责 → 删旧索引 → 按新列定义重建 → 删临时索引。判重逻辑也从"索引是否存在"改为比对 `MAX(seq_in_index)` 与期望列数，否则 2 列改 3 列时索引名没变，只判存在会直接跳过。

顺带一个反向发现：`video_likes`、`video_favorites` 上不需要额外建 `video_id` 索引——InnoDB 已为外键自动创建了同名索引，再建一个是完全重复。

### 5.4 窗口函数与递归 CTE

`database/12_advanced_queries.sql` 五个场景：分类播放 Top3（`ROW_NUMBER() OVER (PARTITION BY ...)`）、分类内占比（`SUM() OVER` 做分母）、每人最近一次播放（分组内取第一行）、共同关注（CTE 求交集）、二度关注（`WITH RECURSIVE`）。

四个实现细节值得记：

- `ORDER BY COUNT(...) DESC, v.id` 里的第二排序键不能省。播放量并列时若不指定次序，`ROW_NUMBER()` 的编号不稳定，两次查询可能取到不同的三条视频，Top3 就不可复现。
- 本场景要"恰好三条"，所以用 `ROW_NUMBER()` 而不是 `RANK()`——后者遇到并列会一次吐出 5、6 条。
- `SUM() OVER ()` 不带 `PARTITION BY` 表示整个结果集，这是窗口函数与聚合函数最本质的区别：聚合把 N 行压成 1 行，窗口保留每一行、只把汇总值附在旁边。
- 递归 CTE 用 `UNION` 而不是 `UNION ALL`：关注关系是稠密图，同一节点可从多条路径到达，`UNION ALL` 会在环上无限展开。但 `depth` 不同行也不同，`UNION` 只能挡住"同深度重复"，真正终止递归的是 `WHERE r.depth < 2`。

二度关注最初返回空集。原因不是 SQL 写错，而是造数脚本把所有关注边都指向同一批 20 个核心用户，`depth=2` 的节点几乎全被 `depth=1` 覆盖，被 `NOT EXISTS` 过滤干净。把生成公式改成"2/3 指向核心用户、1/3 指向随机用户"后稳定返回 10 行以上。同理，分类 Top3 最初只返回一个分类，因为所有视频都用了第一个分类，改成 `@cat_base + (n - 1) % @cat_count` 轮转后 8 个分类各 3 行。

**关系型查询的演示效果高度依赖测试数据的拓扑形状**，纯随机或纯星型的关注数据都跑不出有意义的结果。

### 5.5 造数补强

`07` 补了 2000 条评论（其中 10% 逻辑删除）与 2000 条关注关系，`09` 同步调整分类轮转与关注边公式。两个脚本都用特征串判重（如 `content LIKE '性能评论内容%'`），重复执行不会翻倍。

### 5.6 代码层小修

**（1）匿名访问互动状态接口返回 500。** `/api/videos/{id}/interaction-state` 是公开接口，前端加载详情页时会无条件请求一次。原实现内部调用 `SecurityUtils.currentUserId()`，未登录时抛业务异常，被全局处理器归入"未知异常"分支映射成 500。结果是每个未登录访客打开任意视频详情页，控制台都会出现一条 500。新增 `currentUserIdOrNull()`，未登录返回 `null`，服务层短路返回 `liked = false, favorited = false`。

**（2）互动路径锁粒度从排他锁降到共享锁。** `assertInteractive` 原来用 `SELECT ... FOR UPDATE`，导致同一热门视频上的并发点赞互相排队。改为 `FOR SHARE` 后只与删除的排他锁冲突，并发点赞不再串行——这是用例 2 从阻塞变成 0 ms 的直接原因。评论路径的 `lockById` 同步改为 `shareLockById`，因为它同样只读状态。

**（3）单元测试从 2 个补到 6 个。** 新增重复用户名、空评论、越权删评论、越权删视频四个用例。四个都用 Mockito 校验"是否调用了 Mapper"而不只是"是否抛异常"，这样才能证明校验发生在数据库交互之前。

**（4）格式化 6 个被压成单行的 `.vue` 文件。** 模板部分原本整段写在一行里，最长一行 969 个字符，`git diff` 完全失效。按 Vue 官方风格重排后 `VideoDetailView.vue` 从 108 行变成 222 行、最长行降到 123 字符，其余同理。只动空白与换行，不动逻辑。

顺带在 `PersonalCenterView` 的"全部行为"页签补了分页——该页签复用了行为查询接口，但前端只渲染前 20 条且没有翻页控件，与第二轮补的接口分页能力对不上。

### 5.7 验证

- 全部 12 个 SQL 脚本从空库按序执行通过。
- `e2e-acceptance.sh` 45 → 49 项（新增步骤 10b：审计动作、状态迁移前后值、只改标题不新增、未登录被拒）。
- `mvn test` 6/6 通过；`vite build` 1697 个模块通过。
- 并发脚本重跑两次，五组数字差异在 ±15 ms 以内。
- `init-database.sh` 重写后用替身 `docker` 验证了三条路径：默认流程按 01—06 → 10 → 11 执行、`--perf` 追加 07/08/09/12、`10` 出现非 1644 错误时能正确中止并报错。

---

## 6 关键技术决策记录

| # | 问题 | 选择 | 理由 | 代价 |
|---|---|---|---|---|
| 1 | 点赞/收藏/关注如何同时支持"当前状态"与"历史可追溯" | 当前关系表 + 历史事件表双轨 | 只留当前表会丢历史；只留事件表每次统计当前值都要扫全表并做时序比较 | 写一次要落两张表，需要事务 |
| 2 | 统计值是否缓存进 `videos` | 不缓存，全部由明细聚合 | 从根本上消除"计数与明细不一致" | 列表页聚合开销大，需靠索引与子查询优化 |
| 3 | "已删除视频不能新增互动"放哪一层 | 应用层 `FOR SHARE` 加锁 | 外键指向 `videos.id`，行还在，数据库层拦不住（`11_concurrency.sql` 已证明） | 互动路径多一次加锁读 |
| 4 | 互动路径用 X 锁还是 S 锁 | `FOR SHARE` | 只读状态、不改视频行；S 锁之间兼容，热门视频并发点赞不排队 | 需保证所有写状态的路径都拿 X 锁，否则规则失效 |
| 5 | 审计表是否加外键 | 不加 | 加了 `RESTRICT` 就有审计记录的视频永远无法物理清理 | 审计表与 `videos` 是弱关联，需应用层保证 `video_id` 含义 |
| 6 | 列表页统计用视图还是子查询 | 相关子查询 | 视图会物化全量聚合，代价与视频总数成正比；子查询代价只与返回行数有关 | SQL 变长、不再复用视图；且只能用于按 `videos` 自身列排序 |
| 7 | `videos` 索引是否补 `id DESC` | 补 | 排序要求是 `published_at DESC, id DESC`，补上后 filesort 消失 | 索引多占一列空间；重建需绕过 `ERROR 1553` |
| 8 | 关系分析用自连接还是窗口函数/CTE | 窗口函数 + 递归 CTE | 分组内排名、分组内占比、关系链扩散用传统写法又长又慢 | 递归深度受 `cte_max_recursion_depth` 限制，只适合二度以内 |

---

## 7 踩坑记录

| 现象 | 根因 | 解决 |
|---|---|---|
| `ERROR 1553: Cannot drop index ...: needed in a foreign key constraint` | 被删索引的首列承担外键支撑职责 | 先建替代索引，再删旧索引（出现两次：`idx_play_user_time`、`idx_videos_*_time`） |
| 造出的索引与已有索引完全重复 | InnoDB 已为外键自动创建索引 | `SHOW INDEX` 确认后不建，脚本注释说明原因 |
| 必做查询恒为空集 | `MOD(i, 30)` 与步长 100 的 `gcd` 为 10，日期只覆盖 3 天 | 改用与 30 互质的步长 `MOD(i * 7 + FLOOR(i / 100), 30)` |
| 二度关注返回空集 | 关注边全部指向同一批核心用户，二度被一度覆盖 | 造数改为 2/3 核心 + 1/3 随机 |
| 分类 Top3 只有一个分类 | 所有生成视频都用第一个分类 | 分类按 `(n - 1) % cat_count` 轮转 |
| 并发用例"未阻塞"却显示 600+ ms | 客户端墙钟混入了 `mysql` 客户端启动与连接开销 | 计时改到服务端，用 `NOW(3)` 取差值 |
| 并发用例 3/4/5 看起来什么都没发生 | 重置夹具时删除再重建，自增 `id` 变了，后续仍对死行加锁 | 重置后重新读回 `VID` |
| `scripts/concurrency-test.sh: line 72: VID: unbound variable` | 变量后紧跟中文（`$VID，`），bash 认为变量名延续 | 写成 `${VID}` |
| 事务演示报 `Column 'video_id' cannot be null` | 选定的用户没有 `PUBLISHED` 作品，`@vid` 为 NULL | 改从任意 `PUBLISHED` 视频取 `@vid`，换一个用户当操作者 |
| e2e 期望 401 实得 403 | Spring Security 对未认证请求无入口点时返回 403 | 断言改为 403 |
| `10_triggers.sql` 后续 SELECT 不输出 | `SIGNAL` 中止了整个脚本 | 把"已删除不可恢复"移到最后一步，并文档化 `--force` |
| MyBatis `resultType="map"` 的 key 是 snake_case | 即使开了 `map-underscore-to-camel-case`，Map 也不做转换 | 前端 `row.camelCase ?? row.snake_case` 兜底 |
| `/api/users` 被当成 `/api/users/{id}` 解析 | 路径匹配顺序 | Spring 中字面量路径优先；`antMatchers("/api/users/**")` 能同时匹配两者 |

---

## 8 指标汇总

| 指标 | 第一轮 | 第二轮 | 第三轮 |
|---|---|---|---|
| 端到端断言 | 32 | 45 | **49** |
| 单元测试 | 2 | 2 | **6** |
| 数据库表 | 12 | 12 | **13**（+`video_audit`） |
| 二级索引 | 15 | 15 | **17** |
| SQL 脚本 | 01—09 | 01—09 | **01—12** |
| 首页列表（10 万） | — | — | 33.6 ms → **0.026 ms** |
| 索引查询 A/B/C（10 万） | 0.033 / 0.059 / 9.17 ms | 同左 | 0.034 / 0.061 / 9.31 ms |
| 并发锁等待 | 无实测 | 无实测 | X vs X 1592 ms，S vs S **0 ms** |
| 数据规模 | 1 万 + 10 万 | 同左 | 1 万（109 用户 / 503 视频）＋10 万（1109 / 5503） |

---

## 9 遗留问题与后续计划

按优先级排列：

1. **计数表。** 相关子查询只能用于按 `videos` 自身列排序。一旦要做"最热视频"（按点赞数排序），子查询无法参与排序，必须改用触发器维护的 `video_counters` 表。这是当前列表页方案的硬边界。
2. **Mapper 层集成测试。** 6 个用例全是 Mockito，不连数据库，SQL 写错只能靠 e2e 发现，而 e2e 只覆盖主流程。建议用 Testcontainers 在 CI 里起 MySQL，把 `05`、`12` 的关键查询纳入自动化测试。
3. **死锁实验。** 现有并发实验只覆盖单行锁竞争，没有构造两个事务以相反顺序锁两行的场景，也没观察过 `SHOW ENGINE INNODB STATUS` 的死锁检测与回滚选择。
4. **审计表保留策略。** `video_audit` 只增不删，长期运行会无限膨胀，需要按 `changed_at` 分区或定期归档。
5. **行为查询的 `count` 扫两遍。** 总数是对同一段 `UNION ALL` 再聚合一次。彻底方案是把七段行为物化成 `behavior_log` 宽表（写入时双写），用单表索引同时服务列表与计数。
6. **递归 CTE 只能到二度。** 三度关注在稠密图上会组合爆炸，真要做"可能认识的人"推荐，SQL 递归不是合适的工具。

---

## 10 文件索引

按"哪一轮引入"标注，便于回溯改动来源。

| 路径 | 轮次 | 说明 |
|---|---|---|
| `database/01_schema.sql` | 原有 | 12 张业务表、主外键、`CHECK` |
| `database/02_indexes.sql` | 原有 / **第三轮重写** | 17 个二级索引，`rebuild_videos_index` 按列数判重 |
| `database/03_views.sql` | 原有 | `v_video_statistics` |
| `database/04_seed.sql` | 原有 / **第一轮修哈希** | 测试账号与可核验样例 |
| `database/05_required_queries.sql` | 原有 / **第一轮修时间列** | 2 条关联查询 + 4 条综合统计 |
| `database/06_transaction_demo.sql` | 原有 | 事务成功与回滚存储过程 |
| `database/07_generate_test_data.sql` | 原有 / **第一轮修时间分布** / **第三轮补评论与关注** | 1 万条行为 + 2000 评论 + 2000 关注 |
| `database/08_performance_test.sql` | **第一轮重写** | 索引三组对比 + 列表改写三组对比 |
| `database/09_scale_experiment.sql` | **第一轮新增** / **第三轮调拓扑** | 递归 CTE 扩到 10 万 |
| `database/10_triggers.sql` | **第三轮新增** | `video_audit` + 状态保护与审计触发器 |
| `database/11_concurrency.sql` | **第三轮新增** | 并发夹具与单会话对照 |
| `database/12_advanced_queries.sql` | **第三轮新增** | 窗口函数与递归 CTE 五条查询 |
| `scripts/init-database.sh` | 原有 / **第三轮重写** | 按序执行 01—12，`--perf` 才跑造数 |
| `scripts/e2e-acceptance.sh` | **第一轮新增** | 49 项端到端断言 |
| `scripts/concurrency-test.sh` | **第三轮新增** | 5 组两会话锁竞争，服务端计时 |
| `scripts/build_report_docx.py` | **第三轮新增** | Markdown → Word（pandoc + python-docx） |
| `scripts/make_report_figures.py` | **第一轮新增** | 用 Pillow 画架构图、DFD、E-R 图 |
| `backend/.../VideoMapper.xml` | 原有 / **第三轮改写** | `videoColumns` 改相关子查询，`list`/`detail` 共用 |
| `backend/.../SecurityUtils.java` | 原有 / **第三轮新增方法** | `currentUserIdOrNull()` |
| `backend/.../InteractionService.java` | 原有 / **第三轮改锁** | `FOR SHARE`，匿名返回 false |
| `backend/.../VideoController.java` | 原有 / **第三轮加接口** | `/api/admin/videos/{id}/audit` |
| `backend/src/test/java/**` | **第一轮 2 个** / **第三轮补到 6 个** | Mockito 单元测试 |
| `frontend/src/views/profile/ProfileView.vue` | **第二轮改** | 三页签 + 关注按钮 |
| `frontend/src/views/home/HomeView.vue` | **第二轮改** | 作者远程检索下拉 |
| `frontend/src/views/admin/BehaviorView.vue` | **第二轮改** | 分页控件 |
| `frontend/src/views/**/*.vue`（6 个） | **第三轮重排** | 单行模板格式化 |
| `docs/report/` | **第一轮新增** | 报告 md + docx + 实测日志 + 插图 |
| `docs/development-log.md` | **第三轮新增** | 本文 |
