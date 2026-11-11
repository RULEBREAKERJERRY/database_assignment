# 数据字典

数据库使用 MySQL 8.0、InnoDB、`utf8mb4`。所有 `BIGINT UNSIGNED` 编号均为非负整数；时间精度为毫秒。外键删除策略均为 `RESTRICT`，避免破坏历史记录。

## `users` 用户

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 用户编号 |
| `username` | VARCHAR(50) | 非空 | UK | 登录账号 |
| `password_hash` | VARCHAR(100) | 非空 |  | BCrypt 密码摘要 |
| `nickname` | VARCHAR(50) | 非空 |  | 展示昵称 |
| `bio` | VARCHAR(255) | 非空，`''` |  | 个人简介 |
| `avatar_url` | VARCHAR(255) | 非空，默认头像 |  | 头像地址 |
| `role` | VARCHAR(16) | 非空，`USER` | CHECK `USER/ADMIN` | 权限角色 |
| `status` | VARCHAR(16) | 非空，`ACTIVE` | CHECK `ACTIVE/DISABLED` | 账号状态 |
| `created_at` | DATETIME(3) | 当前时间 |  | 注册时间 |
| `updated_at` | DATETIME(3) | 自动更新 |  | 资料更新时间 |

## `video_categories` 视频分类

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 分类编号 |
| `name` | VARCHAR(40) | 非空 | UK | 分类名称 |
| `sort_order` | INT | 非空，0 | CHECK `>= 0` | 显示顺序 |

## `videos` 视频

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 视频编号 |
| `author_id` | BIGINT UNSIGNED | 非空 | FK → `users.id` | 作者 |
| `category_id` | BIGINT UNSIGNED | 非空 | FK → `video_categories.id` | 分类 |
| `title` | VARCHAR(120) | 非空 | CHECK 去空格后非空 | 标题 |
| `description` | VARCHAR(1000) | 非空，`''` |  | 简介 |
| `file_path` | VARCHAR(500) | 非空 |  | 视频相对地址 |
| `status` | VARCHAR(16) | `PUBLISHED` | CHECK `PUBLISHED/DELETED` | 发布状态 |
| `published_at` | DATETIME(3) | 当前时间 |  | 发布时间 |
| `updated_at` | DATETIME(3) | 自动更新 |  | 修改时间 |
| `deleted_at` | DATETIME(3) | 可空 | 与状态联合 CHECK | 逻辑删除时间 |

## 关注表

### `follow_relations` 当前关注

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `follower_id` | BIGINT UNSIGNED | 非空 | 联合 PK，FK → 用户 | 关注者 |
| `followed_id` | BIGINT UNSIGNED | 非空 | 联合 PK，FK → 用户，CHECK 不同于关注者 | 被关注者 |
| `followed_at` | DATETIME(3) | 当前时间 |  | 本轮关注时间 |

### `follow_events` 关注历史

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 事件编号 |
| `follower_id` | BIGINT UNSIGNED | 非空 | FK → 用户 | 操作者 |
| `followed_id` | BIGINT UNSIGNED | 非空 | FK → 用户，CHECK 不同于操作者 | 操作对象 |
| `event_type` | VARCHAR(16) | 非空 | CHECK `FOLLOW/UNFOLLOW` | 操作类型 |
| `occurred_at` | DATETIME(3) | 当前时间 |  | 发生时间 |
| `request_id` | VARCHAR(64) | 可空 | UK | 幂等请求编号 |

## 点赞表

### `video_likes` 当前点赞

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `user_id` | BIGINT UNSIGNED | 非空 | 联合 PK，FK → 用户 | 点赞用户 |
| `video_id` | BIGINT UNSIGNED | 非空 | 联合 PK，FK → 视频 | 被点赞视频 |
| `liked_at` | DATETIME(3) | 当前时间 |  | 本轮点赞时间 |

### `like_events` 点赞历史

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 事件编号 |
| `user_id` | BIGINT UNSIGNED | 非空 | FK → 用户 | 操作者 |
| `video_id` | BIGINT UNSIGNED | 非空 | FK → 视频 | 操作视频 |
| `event_type` | VARCHAR(16) | 非空 | CHECK `LIKE/UNLIKE` | 操作类型 |
| `occurred_at` | DATETIME(3) | 当前时间 |  | 发生时间 |
| `request_id` | VARCHAR(64) | 可空 | UK | 幂等请求编号 |

## 收藏表

### `video_favorites` 当前收藏

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `user_id` | BIGINT UNSIGNED | 非空 | 联合 PK，FK → 用户 | 收藏用户 |
| `video_id` | BIGINT UNSIGNED | 非空 | 联合 PK，FK → 视频 | 被收藏视频 |
| `favorited_at` | DATETIME(3) | 当前时间 |  | 本轮收藏时间 |

### `favorite_events` 收藏历史

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 事件编号 |
| `user_id` | BIGINT UNSIGNED | 非空 | FK → 用户 | 操作者 |
| `video_id` | BIGINT UNSIGNED | 非空 | FK → 视频 | 操作视频 |
| `event_type` | VARCHAR(16) | 非空 | CHECK `FAVORITE/UNFAVORITE` | 操作类型 |
| `occurred_at` | DATETIME(3) | 当前时间 |  | 发生时间 |
| `request_id` | VARCHAR(64) | 可空 | UK | 幂等请求编号 |

## `play_records` 播放记录

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 播放编号 |
| `user_id` | BIGINT UNSIGNED | 非空 | FK → 用户 | 观看用户 |
| `video_id` | BIGINT UNSIGNED | 非空 | FK → 视频 | 播放视频 |
| `started_at` | DATETIME(3) | 当前时间 |  | 开始播放时间 |
| `request_id` | VARCHAR(64) | 非空 | UK | 幂等请求编号 |

## `share_records` 转发记录

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 转发编号 |
| `user_id` | BIGINT UNSIGNED | 非空 | FK → 用户 | 转发用户 |
| `video_id` | BIGINT UNSIGNED | 非空 | FK → 视频 | 原视频 |
| `shared_at` | DATETIME(3) | 当前时间 |  | 转发时间 |
| `request_id` | VARCHAR(64) | 非空 | UK | 幂等请求编号 |

## `comments` 评论

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 评论编号 |
| `user_id` | BIGINT UNSIGNED | 非空 | FK → 用户 | 评论作者 |
| `video_id` | BIGINT UNSIGNED | 非空 | FK → 视频 | 所属视频 |
| `content` | VARCHAR(1000) | 非空 | CHECK 去空格后非空 | 评论内容 |
| `created_at` | DATETIME(3) | 当前时间 |  | 发表时间 |
| `is_deleted` | BOOLEAN | `FALSE` |  | 逻辑删除标志 |
| `deleted_at` | DATETIME(3) | 可空 | 与删除标志联合 CHECK | 删除时间 |

## `video_audit` 作品状态审计

由 `10_triggers.sql` 创建，记录 `videos.status` 的每一次迁移。**刻意不声明外键**：审计表的职责是"记录发生过什么"，若加 `FK → videos.id` 并沿用全库的 `RESTRICT`，一条有审计记录的视频将永远无法物理清理。

| 字段 | 类型 | 空值/默认 | 键与约束 | 含义 |
|---|---|---|---|---|
| `id` | BIGINT UNSIGNED | 非空，自增 | PK | 审计编号 |
| `video_id` | BIGINT UNSIGNED | 非空 | 索引（无外键） | 被修改的视频 |
| `action` | VARCHAR(16) | 非空 | CHECK `PUBLISH/DELETE` | 动作类型 |
| `old_status` | VARCHAR(16) | 非空 |  | 变更前状态 |
| `new_status` | VARCHAR(16) | 非空 |  | 变更后状态 |
| `old_deleted_at` | DATETIME(3) | 可空 |  | 变更前删除时间 |
| `new_deleted_at` | DATETIME(3) | 可空 |  | 变更后删除时间 |
| `changed_at` | DATETIME(3) | 当前时间 | 索引 | 记录时间 |

索引：`idx_audit_video_time (video_id, changed_at DESC)`、`idx_audit_action_time (action, changed_at DESC)`。

两个触发器：

| 触发器 | 时机 | 作用 |
|---|---|---|
| `trg_videos_prevent_restore` | BEFORE UPDATE | `DELETED → PUBLISHED` 时 `SIGNAL SQLSTATE '45000'`，拒绝恢复 |
| `trg_videos_audit_status` | AFTER UPDATE | `NEW.status <> OLD.status` 时写入一条审计 |

`AFTER UPDATE` 触发器属于所在事务，业务回滚时审计记录一并回滚。

## `v_video_statistics` 普通视图

每个视频一行，字段为 `video_id`、`current_like_count`、`current_favorite_count`、`play_count`、`unique_viewer_count`、`share_count`、`valid_comment_count`。视图从各明细表分别聚合后连接，避免多个一对多表直接连接导致计数相乘。
