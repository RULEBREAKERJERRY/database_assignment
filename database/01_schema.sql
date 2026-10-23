CREATE DATABASE IF NOT EXISTS short_video
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE short_video;

CREATE TABLE IF NOT EXISTS users (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username        VARCHAR(50) NOT NULL,
    password_hash   VARCHAR(100) NOT NULL,
    nickname        VARCHAR(50) NOT NULL,
    bio             VARCHAR(255) NOT NULL DEFAULT '',
    avatar_url      VARCHAR(255) NOT NULL DEFAULT '/default-avatar.png',
    role            VARCHAR(16) NOT NULL DEFAULT 'USER',
    status          VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_username (username),
    CONSTRAINT ck_users_role CHECK (role IN ('USER', 'ADMIN')),
    CONSTRAINT ck_users_status CHECK (status IN ('ACTIVE', 'DISABLED'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS video_categories (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(40) NOT NULL,
    sort_order  INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_categories_name (name),
    CONSTRAINT ck_categories_sort CHECK (sort_order >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS videos (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    author_id     BIGINT UNSIGNED NOT NULL,
    category_id   BIGINT UNSIGNED NOT NULL,
    title         VARCHAR(120) NOT NULL,
    description   VARCHAR(1000) NOT NULL DEFAULT '',
    file_path     VARCHAR(500) NOT NULL,
    status        VARCHAR(16) NOT NULL DEFAULT 'PUBLISHED',
    published_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    deleted_at    DATETIME(3) NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_videos_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_videos_category FOREIGN KEY (category_id) REFERENCES video_categories(id) ON DELETE RESTRICT,
    CONSTRAINT ck_videos_title CHECK (CHAR_LENGTH(TRIM(title)) > 0),
    CONSTRAINT ck_videos_status CHECK (status IN ('PUBLISHED', 'DELETED')),
    CONSTRAINT ck_videos_deleted CHECK (
      (status = 'PUBLISHED' AND deleted_at IS NULL) OR
      (status = 'DELETED' AND deleted_at IS NOT NULL)
    )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS follow_relations (
    follower_id  BIGINT UNSIGNED NOT NULL,
    followed_id  BIGINT UNSIGNED NOT NULL,
    followed_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (follower_id, followed_id),
    CONSTRAINT fk_follow_current_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_follow_current_followed FOREIGN KEY (followed_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT ck_follow_not_self CHECK (follower_id <> followed_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS follow_events (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    follower_id  BIGINT UNSIGNED NOT NULL,
    followed_id  BIGINT UNSIGNED NOT NULL,
    event_type   VARCHAR(16) NOT NULL,
    occurred_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    request_id   VARCHAR(64) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_follow_event_request (request_id),
    CONSTRAINT fk_follow_event_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_follow_event_followed FOREIGN KEY (followed_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT ck_follow_event_not_self CHECK (follower_id <> followed_id),
    CONSTRAINT ck_follow_event_type CHECK (event_type IN ('FOLLOW', 'UNFOLLOW'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS video_likes (
    user_id     BIGINT UNSIGNED NOT NULL,
    video_id    BIGINT UNSIGNED NOT NULL,
    liked_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (user_id, video_id),
    CONSTRAINT fk_like_current_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_like_current_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS like_events (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id      BIGINT UNSIGNED NOT NULL,
    video_id     BIGINT UNSIGNED NOT NULL,
    event_type   VARCHAR(16) NOT NULL,
    occurred_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    request_id   VARCHAR(64) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_like_event_request (request_id),
    CONSTRAINT fk_like_event_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_like_event_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT,
    CONSTRAINT ck_like_event_type CHECK (event_type IN ('LIKE', 'UNLIKE'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS video_favorites (
    user_id       BIGINT UNSIGNED NOT NULL,
    video_id      BIGINT UNSIGNED NOT NULL,
    favorited_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (user_id, video_id),
    CONSTRAINT fk_favorite_current_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_favorite_current_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS favorite_events (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id      BIGINT UNSIGNED NOT NULL,
    video_id     BIGINT UNSIGNED NOT NULL,
    event_type   VARCHAR(16) NOT NULL,
    occurred_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    request_id   VARCHAR(64) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_favorite_event_request (request_id),
    CONSTRAINT fk_favorite_event_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_favorite_event_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT,
    CONSTRAINT ck_favorite_event_type CHECK (event_type IN ('FAVORITE', 'UNFAVORITE'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS play_records (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id     BIGINT UNSIGNED NOT NULL,
    video_id    BIGINT UNSIGNED NOT NULL,
    started_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    request_id  VARCHAR(64) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_play_request (request_id),
    CONSTRAINT fk_play_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_play_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS share_records (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id     BIGINT UNSIGNED NOT NULL,
    video_id    BIGINT UNSIGNED NOT NULL,
    shared_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    request_id  VARCHAR(64) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_share_request (request_id),
    CONSTRAINT fk_share_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_share_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS comments (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id     BIGINT UNSIGNED NOT NULL,
    video_id    BIGINT UNSIGNED NOT NULL,
    content     VARCHAR(1000) NOT NULL,
    created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    is_deleted  BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at  DATETIME(3) NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_comment_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_comment_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE RESTRICT,
    CONSTRAINT ck_comment_content CHECK (CHAR_LENGTH(TRIM(content)) > 0),
    CONSTRAINT ck_comment_deleted CHECK (
      (is_deleted = FALSE AND deleted_at IS NULL) OR
      (is_deleted = TRUE AND deleted_at IS NOT NULL)
    )
) ENGINE=InnoDB;

