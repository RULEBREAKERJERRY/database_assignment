# 核心接口

除注册登录、公开视频查询、用户检索外，接口均需请求头：

```text
Authorization: Bearer <JWT>
```

关注、播放、点赞、收藏和转发还需提供：

```text
Idempotency-Key: <UUID>
```

## 接口清单

| 方法 | 路径 | 用途 |
|---|---|---|
| POST | `/api/auth/register` | 注册并登录 |
| POST | `/api/auth/login` | 登录 |
| GET | `/api/auth/me` | 当前用户资料 |
| PUT | `/api/me/profile` | 修改昵称和简介 |
| GET | `/api/users?keyword=&limit=` | 用户检索，昵称/用户名模糊匹配，按粉丝数降序 |
| GET | `/api/users/{id}` | 用户资料（含粉丝数、关注数） |
| GET | `/api/users/{id}/following` | 关注列表，含 `followed_at` |
| GET | `/api/users/{id}/followers` | 粉丝列表，含 `followed_at` |
| GET | `/api/categories` | 分类列表 |
| GET/POST | `/api/videos` | 查询（`keyword`/`authorId`/`categoryId`）/上传视频 |
| GET/PUT/DELETE | `/api/videos/{id}` | 详情/修改/逻辑删除 |
| GET | `/api/me/videos` | 我的作品（含未发布） |
| POST | `/api/videos/{id}/play` | 记录播放 |
| POST/DELETE | `/api/videos/{id}/like` | 点赞/取消点赞 |
| POST/DELETE | `/api/videos/{id}/favorite` | 收藏/取消收藏 |
| POST | `/api/videos/{id}/share` | 站内转发 |
| GET | `/api/videos/{id}/interaction-state` | 当前用户对该视频的点赞/收藏状态 |
| GET/POST | `/api/videos/{id}/comments` | 评论列表/发表评论 |
| DELETE | `/api/comments/{id}` | 逻辑删除本人评论 |
| POST/DELETE | `/api/follows/{userId}` | 关注/取消关注 |
| GET | `/api/follows/{userId}/state` | 是否已关注 |
| GET | `/api/me/history?start=&end=` | 本人观看历史，可按 ISO 时间范围过滤 |
| GET | `/api/me/behaviors` | 本人行为查询，分页 |
| GET | `/api/admin/behaviors` | 管理员全局行为查询，分页 |
| GET | `/api/videos/{id}/statistics` | 视频统计 |
| GET | `/api/users/{id}/statistics` | 用户统计 |
| GET | `/api/admin/videos/{id}/audit` | 管理员查看作品审计轨迹（仅 `ADMIN`） |

## 分页约定

所有列表型接口统一返回 `PageResult`，不再直接返回数组：

```json
{ "items": [], "total": 0, "page": 1, "size": 20 }
```

适用接口：`/api/videos`、`/api/me/videos`、`/api/videos/{id}/comments`、`/api/me/behaviors`、`/api/admin/behaviors`。

请求参数统一为 `page`（从 1 开始）与 `size`（默认 12 或 20，行为查询上限 100）。

## 说明

- 行为查询的 `total` 与列表使用同一段 `UNION ALL` 数据源和同一组筛选条件，只额外做一次 `COUNT(*)`，避免出现「页码算出来 3 页、翻到第 3 页却是空」的情况。
- `/api/users` 与 `/api/users/{id}` 同时存在时，Spring 优先匹配字面量路径 `/api/users`，不会把 `users` 当成 `{id}` 解析。
- `/api/videos/{id}/interaction-state` 是公开接口。未登录时返回 `{"liked": false, "favorited": false}`，不抛异常——前端加载详情页会无条件请求一次该接口，抛异常会让每个匿名访客都看到一条 500。

## 审计轨迹

`GET /api/admin/videos/{id}/audit` 返回由 `AFTER UPDATE` 触发器写入的记录，按时间倒序：

```json
{
  "code": 0,
  "data": [
    {
      "id": 12,
      "video_id": 7,
      "action": "DELETE",
      "old_status": "PUBLISHED",
      "new_status": "DELETED",
      "changed_at": "2026-11-11 14:44:33.490"
    }
  ]
}
```

`action` 取值为 `PUBLISH` 或 `DELETE`；只有 `status` 真正发生变化时才会产生记录，改标题、改简介不会写入。未登录访问返回 403，普通用户访问同样返回 403。
