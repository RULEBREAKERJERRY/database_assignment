# 短视频数据管理系统

数据库课程设计项目，覆盖视频发布、播放、关注、点赞、收藏、转发、评论、行为追溯与统计分析。

## 技术栈

- Java 11、Spring Boot 2.7、Spring Security、JWT、MyBatis
- Vue 3、TypeScript、Vite、Element Plus
- MySQL 8.0

> 当前开发机为 Java 11，因此采用支持 Java 11 的 Spring Boot 2.7。业务结构与 Spring Boot 3 方案一致。

## 快速启动

### 1. 启动数据库

复制环境配置并启动 MySQL：

```bash
cp .env.example .env
docker compose up -d mysql
```

MySQL 首次创建数据卷时会自动执行 `database/01_schema.sql` 至 `04_seed.sql`。

### 2. 启动后端

需要 Java 11+ 和 Maven 3.8+：

```bash
cd backend
export JAVA_HOME="$(/usr/libexec/java_home -v 11)" # macOS 多 JDK 环境需要
mvn spring-boot:run
```

也可以在项目根目录执行 `./scripts/start-backend.sh`，脚本会在 macOS 上自动选择 Java 11。

后端默认地址：`http://localhost:8080`。

### 3. 启动前端

需要 Node.js 18+：

```bash
cd frontend
npm install
npm run dev
```

访问 `http://localhost:5173`。

## 测试账号

初始化账号的密码均为 `password`：

| 账号 | 身份 |
|---|---|
| `admin` | 管理员 |
| `alice` | 普通用户 |
| `bob` | 普通用户 |

这些账号仅供本地课程演示，正式部署前必须修改密码与 JWT 密钥。

初始化后首页包含一条可播放的 CC0 示例视频和一组可人工核验的互动历史；素材来源说明见 [storage/videos/README.md](storage/videos/README.md)。

## 数据库脚本

脚本用途与执行顺序见 [database/README.md](database/README.md)。核心内容包括：

- 主键、外键、唯一约束和 `CHECK` 约束
- 当前关系与历史事件分离
- 视频统计普通视图
- 必做关联查询及四项综合统计查询
- 点赞成功与失败回滚演示
- 100 用户、500 视频及至少 1 万行为的可重复数据脚本
- 联合索引的 `EXPLAIN ANALYZE` 对比实验

## 文件存储

上传视频保存在 `storage/videos/`，数据库只保存 `/media/videos/...` 相对地址。该目录中的运行期文件默认不提交版本控制。

## 权限与统计口径

- 普通用户只能修改自己的资料、视频和评论，只能查询自己的完整行为。
- 管理员可以使用行为查询页检索全局记录。
- 视频和评论使用逻辑删除，历史行为不级联删除。
- 点赞、收藏、关注统计当前有效关系；播放和转发统计累计成功记录；评论统计未删除记录。
- 播放、转发请求使用 `Idempotency-Key` 防止同一请求重试造成重复数据。

更多设计说明见 [docs/database-design.md](docs/database-design.md)、[docs/data-dictionary.md](docs/data-dictionary.md) 和 [docs/test-and-acceptance.md](docs/test-and-acceptance.md)。

