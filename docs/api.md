# 核心接口

除注册登录、公开视频查询外，接口均需请求头：

```text
Authorization: Bearer <JWT>
```

关注、播放、点赞、收藏和转发还需提供：

```text
Idempotency-Key: <UUID>
```

| 方法 | 路径 | 用途 |
|---|---|---|
| POST | `/api/auth/register` | 注册并登录 |
| POST | `/api/auth/login` | 登录 |
| GET | `/api/auth/me` | 当前用户资料 |
| PUT | `/api/me/profile` | 修改昵称和简介 |
| GET/POST | `/api/videos` | 查询/上传视频 |
| GET/PUT/DELETE | `/api/videos/{id}` | 详情/修改/逻辑删除 |
| POST | `/api/videos/{id}/play` | 记录播放 |
| POST/DELETE | `/api/videos/{id}/like` | 点赞/取消点赞 |
| POST/DELETE | `/api/videos/{id}/favorite` | 收藏/取消收藏 |
| POST | `/api/videos/{id}/share` | 站内转发 |
| GET/POST | `/api/videos/{id}/comments` | 评论列表/发表评论 |
| DELETE | `/api/comments/{id}` | 逻辑删除本人评论 |
| POST/DELETE | `/api/follows/{userId}` | 关注/取消关注 |
| GET | `/api/me/history?start=&end=` | 本人观看历史，可按 ISO 时间范围过滤 |
| GET | `/api/me/behaviors` | 本人行为查询 |
| GET | `/api/admin/behaviors` | 管理员全局行为查询 |
| GET | `/api/videos/{id}/statistics` | 视频统计 |
| GET | `/api/users/{id}/statistics` | 用户统计 |

