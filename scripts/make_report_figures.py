#!/usr/bin/env python3
"""生成课程设计报告所需插图（架构图、数据流图、E-R 图）。

仅依赖 Pillow，输出 PNG 到 docs/report/figures/。
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "report", "figures")
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)

FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
S = 2  # 超采样倍数

INK = "#2C2C2A"
MUTED = "#5F5E5A"
LINE = "#7A7973"
BORDER = "#C9C7BE"
HEAD = "#2F5D4E"
HEAD2 = "#8A4B2A"
FILL = "#FFFFFF"
SOFT = "#F3F1EA"
PILL = "#FAEEDA"
PILL_INK = "#7A4A0C"
STORE = "#E8F1EC"


def f(size):
    return ImageFont.truetype(FONT, int(size * S))


def canvas(w, h, bg="#FFFFFF"):
    img = Image.new("RGB", (w * S, h * S), bg)
    return img, ImageDraw.Draw(img)


def save(img, w, h, name):
    img = img.resize((w, h), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    print("saved", path)


def text(d, xy, s, size=13, fill=INK, anchor="la"):
    if "\n" in s:
        d.multiline_text((xy[0] * S, xy[1] * S), s, font=f(size), fill=fill,
                         anchor=anchor, align="center", spacing=6 * S)
    else:
        d.text((xy[0] * S, xy[1] * S), s, font=f(size), fill=fill, anchor=anchor)


def measure(d, s, size):
    font = f(size)
    return max(d.textlength(line, font=font) for line in s.split("\n")) / S


def center_text(d, box, s, size=13, fill=INK):
    x = (box[0] + box[2]) / 2
    y = (box[1] + box[3]) / 2
    text(d, (x, y), s, size, fill, anchor="mm")


def rrect(d, box, r=8, fill=FILL, outline=BORDER, width=1.4):
    d.rounded_rectangle(
        [box[0] * S, box[1] * S, box[2] * S, box[3] * S],
        radius=r * S, fill=fill, outline=outline, width=max(1, int(width * S)),
    )


def line(d, p1, p2, fill=LINE, width=1.4, dash=None):
    if dash is None:
        d.line([p1[0] * S, p1[1] * S, p2[0] * S, p2[1] * S], fill=fill, width=max(1, int(width * S)))
        return
    total = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
    if total == 0:
        return
    ux, uy = (p2[0] - p1[0]) / total, (p2[1] - p1[1]) / total
    pos = 0
    while pos < total:
        end = min(pos + dash[0], total)
        d.line([(p1[0] + ux * pos) * S, (p1[1] + uy * pos) * S,
                (p1[0] + ux * end) * S, (p1[1] + uy * end) * S],
               fill=fill, width=max(1, int(width * S)))
        pos += dash[0] + dash[1]


def arrow(d, p1, p2, fill=LINE, width=1.4, head=7, label=None, dash=None,
          label_off=(0, -12), label_size=12):
    line(d, p1, p2, fill=fill, width=width, dash=dash)
    ang = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
    for sign in (0.42, -0.42):
        d.line([p2[0] * S, p2[1] * S,
                (p2[0] - head * math.cos(ang - sign)) * S,
                (p2[1] - head * math.sin(ang - sign)) * S],
               fill=fill, width=max(1, int(width * S)))
    if label:
        mx, my = (p1[0] + p2[0]) / 2 + label_off[0], (p1[1] + p2[1]) / 2 + label_off[1]
        tw = measure(d, label, label_size)
        th = 16 * len(label.split("\n")) + 4
        d.rectangle([(mx - tw / 2 - 4) * S, (my - th / 2) * S,
                     (mx + tw / 2 + 4) * S, (my + th / 2) * S], fill="#FFFFFF")
        text(d, (mx, my), label, label_size, MUTED, anchor="mm")


def entity(d, x, y, w, title, attrs, head_fill=HEAD, row_h=22):
    h = 34 + row_h * len(attrs) + 18
    rrect(d, (x, y, x + w, y + h), r=9, fill=FILL, outline=BORDER)
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + 34) * S], radius=9 * S,
                        fill=head_fill)
    d.rectangle([x * S, (y + 24) * S, (x + w) * S, (y + 34) * S], fill=head_fill)
    center_text(d, (x, y, x + w, y + 34), title, 14, "#FFFFFF")
    for i, a in enumerate(attrs):
        name, typ, tag = a
        ry = y + 34 + i * row_h + row_h / 2
        text(d, (x + 10, ry), name, 12, INK, anchor="lm")
        if tag:
            tw = measure(d, tag, 10)
            d.rounded_rectangle([(x + w - 10 - tw - 8) * S, (ry - 8) * S,
                                 (x + w - 10) * S, (ry + 8) * S],
                                radius=4 * S, fill="#EDEAE0")
            text(d, (x + w - 14 - tw, ry), tag, 10, "#6B5B33", anchor="lm")
        text(d, (x + w - 24 - (measure(d, tag, 10) if tag else 0), ry),
             typ, 10, MUTED, anchor="rm")
    return h


def pill(d, cx, cy, s, fill=PILL, ink=PILL_INK, size=12):
    tw = measure(d, s, size)
    w, h = tw + 16, 20
    d.rounded_rectangle([(cx - w / 2) * S, (cy - h / 2) * S, (cx + w / 2) * S, (cy + h / 2) * S],
                        radius=10 * S, fill=fill)
    text(d, (cx, cy), s, size, ink, anchor="mm")
    return w, h


def store(d, x, y, w, h, tag, name):
    rrect(d, (x, y, x + w, y + h), r=4, fill=STORE, outline="#9DB6A8")
    line(d, (x + 30, y), (x + 30, y + h), fill="#9DB6A8")
    center_text(d, (x, y, x + 30, y + h), tag, 11, "#3F6354")
    text(d, (x + 40, y + h / 2), name, 12, INK, anchor="lm")


# ---------------------------------------------------------------- 图1 架构
def fig_architecture():
    w, h = 1180, 600
    img, d = canvas(w, h)

    text(d, (20, 22), "图 1  系统总体架构", 15, INK)
    text(d, (20, 44), "浏览器 / Vue3 SPA  →  Spring Boot REST API  →  MySQL 8.0 InnoDB，视频文件独立存放", 12, MUTED)

    # 表现层
    rrect(d, (40, 90, 1140, 190), r=10, fill="#FAF9F5", outline=BORDER)
    text(d, (56, 102), "表现层（浏览器）", 13, HEAD)
    for i, (t, sub) in enumerate([("发现页", "搜索 / 分类 / 排序"), ("视频详情", "播放 / 点赞 / 收藏 / 转发"),
                                  ("发布与作品管理", "上传 / 编辑 / 逻辑删除"), ("个人中心", "历史 / 互动 / 统计"),
                                  ("行为查询", "本人 / 管理员")]):
        x = 56 + i * 218
        rrect(d, (x, 126, x + 200, 176), r=8, fill="#FFFFFF", outline=BORDER)
        text(d, (x + 10, 134), t, 12.5, INK)
        text(d, (x + 10, 154), sub, 10.5, MUTED)

    # 接口层
    rrect(d, (40, 220, 1140, 296), r=10, fill="#F4F7F5", outline=BORDER)
    text(d, (56, 232), "接口层（Spring Security + JWT）", 13, HEAD)
    for i, t in enumerate(["/api/auth/*", "/api/videos/*", "/api/videos/{id}/{play|like|favorite|share}",
                           "/api/me/*", "/api/admin/behaviors"]):
        x = 56 + i * 218
        rrect(d, (x, 254, x + 200, 282), r=6, fill="#FFFFFF", outline=BORDER)
        center_text(d, (x, 254, x + 200, 282), t, 10.5, INK)

    # 业务层
    rrect(d, (40, 326, 1140, 452), r=10, fill="#FAF9F5", outline=BORDER)
    text(d, (56, 338), "业务层（Service，@Transactional 事务边界）", 13, HEAD)
    for i, (t, sub) in enumerate([("AuthService", "注册 / 登录 / BCrypt"), ("VideoService", "上传 / 编辑 / 删除"),
                                  ("InteractionService", "播放 / 点赞 / 收藏 / 转发"),
                                  ("CommentService", "发表 / 逻辑删除"), ("FollowService", "关注 / 取消关注")]):
        x = 56 + i * 218
        rrect(d, (x, 362, x + 200, 438), r=8, fill="#FFFFFF", outline=BORDER)
        text(d, (x + 10, 372), t, 12, HEAD2)
        text(d, (x + 10, 392), sub, 10.5, MUTED)

    # 数据层
    rrect(d, (40, 482, 560, 578), r=10, fill="#F4F7F5", outline=BORDER)
    text(d, (56, 494), "数据层（MyBatis Mapper / 视图 / 存储过程）", 13, HEAD)
    for i, t in enumerate(["12 张基础表", "v_video_statistics 视图", "15 个索引", "幂等唯一键"]):
        x = 56 + (i % 2) * 250
        y = 508 + (i // 2) * 34
        rrect(d, (x, y, x + 230, y + 26), r=6, fill="#FFFFFF", outline=BORDER)
        center_text(d, (x, y, x + 230, y + 26), t, 11, INK)

    rrect(d, (600, 482, 1140, 578), r=10, fill="#F4F7F5", outline=BORDER)
    text(d, (616, 494), "文件存储", 13, HEAD)
    rrect(d, (616, 508, 1124, 548), r=6, fill="#FFFFFF", outline=BORDER)
    center_text(d, (616, 508, 1124, 548), "storage/videos/*.mp4  →  /media/videos/**  静态映射", 11.5, INK)
    text(d, (616, 562), "数据库仅保存相对路径，避免大对象入库", 10.5, MUTED)

    arrow(d, (590, 190), (590, 216), fill=LINE)
    arrow(d, (590, 296), (590, 322), fill=LINE)
    arrow(d, (300, 452), (300, 478), fill=LINE)
    arrow(d, (870, 452), (870, 478), fill=LINE)

    save(img, w, h, "fig1-architecture.png")


# ---------------------------------------------------------------- 图2 顶层DFD
def fig_dfd0():
    w, h = 1000, 340
    img, d = canvas(w, h)
    text(d, (20, 22), "图 2  顶层数据流图（第 0 层）", 15, INK)
    text(d, (20, 44), "把整个平台视为一个处理，只描述外部实体与系统之间的输入输出数据流", 12, MUTED)

    rrect(d, (40, 120, 190, 190), r=6, fill=FILL, outline=BORDER)
    center_text(d, (40, 120, 190, 190), "普通用户", 14, INK)
    rrect(d, (810, 120, 960, 190), r=6, fill=FILL, outline=BORDER)
    center_text(d, (810, 120, 960, 190), "平台管理员", 14, INK)

    d.ellipse([400 * S, 110 * S, 600 * S, 230 * S], fill="#EAF0EC", outline="#8FA99C", width=2 * S)
    center_text(d, (400, 110, 600, 230), "短视频数据\n管理系统", 14, "#1F4A3C")

    arrow(d, (190, 142), (398, 142), label="注册登录、上传、播放、点赞收藏转发评论", label_off=(0, -13), label_size=11)
    arrow(d, (398, 196), (190, 196), label="作品列表、详情、本人历史与统计", label_off=(0, 13), label_size=11)
    arrow(d, (810, 142), (602, 142), label="全局行为查询条件", label_off=(0, -13), label_size=11)
    arrow(d, (602, 196), (810, 196), label="全平台明细与统计结果", label_off=(0, 13), label_size=11)

    save(img, w, h, "fig2-dfd0.png")


def fig_dfd1():
    w, h = 1120, 620
    img, d = canvas(w, h)
    text(d, (20, 22), "图 3  第一层数据流图", 15, INK)
    text(d, (20, 44), "左侧为外部实体，中部为四个处理，右侧为五个数据存储；实线为写入，虚线为读取", 12, MUTED)

    rrect(d, (30, 152, 180, 212), r=6, fill=FILL, outline=BORDER)
    center_text(d, (30, 152, 180, 212), "普通用户", 13, INK)
    rrect(d, (30, 470, 180, 530), r=6, fill=FILL, outline=BORDER)
    center_text(d, (30, 470, 180, 530), "平台管理员", 13, INK)

    procs = [("P1", "账号与资料管理", 152), ("P2", "作品发布与浏览", 254),
             ("P3", "互动记录", 356), ("P4", "查询与统计", 470)]
    for tag, name, y in procs:
        rrect(d, (250, y, 470, y + 60), r=10, fill="#EAF0EC", outline="#8FA99C")
        text(d, (262, y + 10), tag, 11, "#3F6354")
        center_text(d, (250, y, 470, y + 60), name, 13.5, "#1F4A3C")

    stores = [("D1", "用户表 users", 152), ("D2", "视频表 videos", 224),
              ("D3", "关注表 follow_relations / follow_events", 296),
              ("D4", "互动表 play / like / favorite / share", 356),
              ("D5", "评论表 comments", 416)]
    for tag, name, y in stores:
        store(d, 640, y, 450, 46, tag, name)

    # 实体 → 处理
    arrow(d, (180, 166), (248, 166), label="账号、密码", label_off=(0, -11), label_size=10.5)
    arrow(d, (248, 198), (182, 198), label="令牌", label_off=(0, 11), label_size=10.5)
    arrow(d, (180, 210), (248, 276), label="作品信息", label_off=(-6, 12), label_size=10.5)
    arrow(d, (180, 214), (248, 380), label="播放、点赞、\n收藏、转发、评论", label_off=(-2, 26), label_size=10.5)
    arrow(d, (180, 500), (248, 500), label="全局查询条件", label_off=(0, -11), label_size=10.5)

    # 处理 ↔ 存储（水平短线）
    line(d, (470, 182), (638, 182), fill=LINE, width=1.3)
    pill(d, 554, 182, "读写 D1", size=10.5)
    line(d, (470, 284), (638, 284), fill=LINE, width=1.3)
    pill(d, 554, 284, "读写 D2", size=10.5)

    # P3 写 D3 / D4 / D5
    for y in (320, 386, 446):
        line(d, (470, 386), (638, y), fill=LINE, width=1.3)
    pill(d, 552, 322, "写 D3", size=10.5)
    pill(d, 552, 404, "写 D4", size=10.5)
    pill(d, 552, 462, "写 D5", size=10.5)

    # P4 读 D2 / D3 / D4 / D5（虚线）
    for y in (238, 310, 372, 430):
        line(d, (470, 500), (638, y), fill="#9AA8A1", width=1.2, dash=(6, 4))
    pill(d, 556, 520, "读取 D2—D5 生成统计", size=10.5)

    text(d, (30, 586), "P1 维护 D1；P2 维护 D2；P3 向 D3/D4/D5 追加行为记录；P4 汇总 D2—D5 生成视图与统计结果。", 11, MUTED)

    save(img, w, h, "fig3-dfd1.png")


def fig_er():
    w, h = 1240, 760
    img, d = canvas(w, h)
    text(d, (20, 22), "图 4  概念结构 E-R 图", 15, INK)
    text(d, (20, 44), "方框为实体，连线两端标注基数；1:N 与 M:N 联系均带参与属性", 12, MUTED)

    ux, uy, uw = 60, 190, 250
    vx, vy, vw = 660, 190, 270
    uh = entity(d, ux, uy, uw, "用户 users", [
        ("id", "BIGINT", "PK"), ("username", "VARCHAR(50)", "UK"),
        ("password_hash", "VARCHAR(100)", ""), ("nickname", "VARCHAR(50)", ""),
        ("role", "VARCHAR(16)", ""), ("created_at", "DATETIME(3)", ""),
    ])
    vh = entity(d, vx, vy, vw, "视频 videos", [
        ("id", "BIGINT", "PK"), ("author_id", "BIGINT", "FK"),
        ("category_id", "BIGINT", "FK"), ("title", "VARCHAR(120)", ""),
        ("file_path", "VARCHAR(500)", ""), ("status", "VARCHAR(16)", ""),
        ("published_at", "DATETIME(3)", ""),
    ])

    cx, cy = 990, 210
    entity(d, cx, cy, 218, "分类 video_categories", [
        ("id", "BIGINT", "PK"), ("name", "VARCHAR(40)", "UK"), ("sort_order", "INT", ""),
    ])

    # 用户-视频 五条联系（发布、点赞、收藏、播放、转发）
    rels = [("发布", "1", "N", "published_at"), ("点赞", "M", "N", "liked_at"),
            ("收藏", "M", "N", "favorited_at"), ("播放", "M", "N", "started_at"),
            ("转发", "M", "N", "shared_at")]
    top = uy + 44
    for i, (name, c1, c2, attr) in enumerate(rels):
        y = top + i * 30
        line(d, (ux + uw, y), (vx, y), fill=LINE, width=1.3)
        pill(d, (ux + uw + vx) / 2, y, name, size=11.5)
        text(d, (ux + uw + 10, y - 10), c1, 10.5, "#8A4B2A")
        text(d, (vx - 14, y - 10), c2, 10.5, "#8A4B2A")
        text(d, (ux + uw + 118, y + 11), attr, 9.5, MUTED, anchor="ma")

    # 视频-分类
    line(d, (vx + vw, cy + 30), (cx, cy + 30), fill=LINE, width=1.3)
    pill(d, vx + vw + 26, cy + 12, "属于", size=11)
    text(d, (vx + vw + 6, cy + 42), "N", 10.5, "#8A4B2A")
    text(d, (cx - 10, cy + 42), "1", 10.5, "#8A4B2A")

    # 关注：自反
    d.arc([(ux + 56) * S, (uy - 88) * S, (ux + 204) * S, (uy + 4) * S],
          start=180, end=360, fill=LINE, width=int(1.3 * S))
    line(d, (ux + 56, uy - 42), (ux + 56, uy), fill=LINE, width=1.3)
    line(d, (ux + 204, uy - 42), (ux + 204, uy), fill=LINE, width=1.3)
    pill(d, ux + 130, uy - 104, "关注 M:N（自反）", size=11)
    text(d, (ux + 44, uy - 34), "M", 10.5, "#8A4B2A")
    text(d, (ux + 208, uy - 34), "N", 10.5, "#8A4B2A")

    # 评论实体
    mx, my = 660, 560
    entity(d, mx, my, 270, "评论 comments", [
        ("id", "BIGINT", "PK"), ("user_id", "BIGINT", "FK"),
        ("video_id", "BIGINT", "FK"), ("content", "VARCHAR(1000)", ""),
        ("is_deleted", "BOOLEAN", ""), ("deleted_at", "DATETIME(3)", ""),
    ])
    line(d, (vx + 120, vy + vh), (mx + 120, my), fill=LINE, width=1.3)
    pill(d, vx + 150, my - 34, "拥有 1:N", size=11)
    text(d, (vx + 126, vy + vh + 6), "1", 10.5, "#8A4B2A")
    text(d, (mx + 126, my - 16), "N", 10.5, "#8A4B2A")

    line(d, (ux + uw - 40, uy + uh), (mx + 20, my), fill=LINE, width=1.3)
    pill(d, ux + uw + 40, my - 60, "发表 1:N", size=11)
    text(d, (ux + uw - 34, uy + uh + 6), "1", 10.5, "#8A4B2A")
    text(d, (mx + 26, my - 14), "N", 10.5, "#8A4B2A")

    text(d, (60, 720),
         "说明：当前关系表（video_likes / video_favorites / follow_relations）承载 M:N 的“当前状态”，"
         "同名 *_events 表记录每次操作的类型与时间，二者共同满足“当前统计 + 历史可追溯”。", 10.5, MUTED)

    save(img, w, h, "fig4-er.png")


if __name__ == "__main__":
    fig_architecture()
    fig_dfd0()
    fig_dfd1()
    fig_er()
