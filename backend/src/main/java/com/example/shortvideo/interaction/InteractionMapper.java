package com.example.shortvideo.interaction;

import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface InteractionMapper {
    @Insert("INSERT IGNORE INTO video_likes(user_id, video_id) VALUES(#{userId}, #{videoId})")
    int addLike(@Param("userId") Long userId, @Param("videoId") Long videoId);

    @Delete("DELETE FROM video_likes WHERE user_id=#{userId} AND video_id=#{videoId}")
    int removeLike(@Param("userId") Long userId, @Param("videoId") Long videoId);

    @Insert("INSERT INTO like_events(user_id, video_id, event_type, request_id) " +
            "VALUES(#{userId}, #{videoId}, #{type}, #{requestId})")
    int addLikeEvent(@Param("userId") Long userId, @Param("videoId") Long videoId,
                     @Param("type") String type, @Param("requestId") String requestId);

    @Select("SELECT COUNT(*) FROM video_likes WHERE user_id=#{userId} AND video_id=#{videoId}")
    int hasLiked(@Param("userId") Long userId, @Param("videoId") Long videoId);

    @Insert("INSERT IGNORE INTO video_favorites(user_id, video_id) VALUES(#{userId}, #{videoId})")
    int addFavorite(@Param("userId") Long userId, @Param("videoId") Long videoId);

    @Delete("DELETE FROM video_favorites WHERE user_id=#{userId} AND video_id=#{videoId}")
    int removeFavorite(@Param("userId") Long userId, @Param("videoId") Long videoId);

    @Insert("INSERT INTO favorite_events(user_id, video_id, event_type, request_id) " +
            "VALUES(#{userId}, #{videoId}, #{type}, #{requestId})")
    int addFavoriteEvent(@Param("userId") Long userId, @Param("videoId") Long videoId,
                         @Param("type") String type, @Param("requestId") String requestId);

    @Select("SELECT COUNT(*) FROM video_favorites WHERE user_id=#{userId} AND video_id=#{videoId}")
    int hasFavorited(@Param("userId") Long userId, @Param("videoId") Long videoId);

    @Insert("INSERT IGNORE INTO play_records(user_id, video_id, request_id) VALUES(#{userId}, #{videoId}, #{requestId})")
    int addPlay(@Param("userId") Long userId, @Param("videoId") Long videoId,
                @Param("requestId") String requestId);

    @Insert("INSERT IGNORE INTO share_records(user_id, video_id, request_id) VALUES(#{userId}, #{videoId}, #{requestId})")
    int addShare(@Param("userId") Long userId, @Param("videoId") Long videoId,
                 @Param("requestId") String requestId);

    @Select("SELECT v.id, v.title, v.file_path, u.nickname author_name, l.liked_at " +
            "FROM video_likes l JOIN videos v ON v.id=l.video_id JOIN users u ON u.id=v.author_id " +
            "WHERE l.user_id=#{userId} AND v.status='PUBLISHED' ORDER BY l.liked_at DESC")
    List<Map<String, Object>> currentLikes(Long userId);

    @Select("SELECT v.id, v.title, v.file_path, u.nickname author_name, f.favorited_at " +
            "FROM video_favorites f JOIN videos v ON v.id=f.video_id JOIN users u ON u.id=v.author_id " +
            "WHERE f.user_id=#{userId} AND v.status='PUBLISHED' ORDER BY f.favorited_at DESC")
    List<Map<String, Object>> currentFavorites(Long userId);

    @Select("SELECT p.id, p.video_id, v.title, u.nickname author_name, p.started_at " +
            "FROM play_records p JOIN videos v ON v.id=p.video_id JOIN users u ON u.id=v.author_id " +
            "WHERE p.user_id=#{userId} " +
            "AND (#{start} IS NULL OR p.started_at >= #{start}) " +
            "AND (#{end} IS NULL OR p.started_at <= #{end}) " +
            "ORDER BY p.started_at DESC LIMIT #{size} OFFSET #{offset}")
    List<Map<String, Object>> playHistory(@Param("userId") Long userId,
                                          @Param("start") java.time.LocalDateTime start,
                                          @Param("end") java.time.LocalDateTime end,
                                          @Param("offset") int offset, @Param("size") int size);
}

