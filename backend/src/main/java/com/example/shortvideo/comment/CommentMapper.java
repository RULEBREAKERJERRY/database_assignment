package com.example.shortvideo.comment;

import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface CommentMapper {
    @Insert("INSERT INTO comments(user_id, video_id, content) VALUES(#{userId}, #{videoId}, #{content})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Comment comment);

    @Select("SELECT c.id, c.user_id, u.nickname author_name, u.avatar_url, c.content, c.created_at " +
            "FROM comments c JOIN users u ON u.id=c.user_id " +
            "WHERE c.video_id=#{videoId} AND c.is_deleted=FALSE " +
            "ORDER BY c.created_at DESC, c.id DESC LIMIT #{size} OFFSET #{offset}")
    List<Map<String, Object>> list(@Param("videoId") Long videoId,
                                   @Param("offset") int offset, @Param("size") int size);

    @Select("SELECT COUNT(*) FROM comments WHERE video_id=#{videoId} AND is_deleted=FALSE")
    long count(Long videoId);

    @Update("UPDATE comments SET is_deleted=TRUE, deleted_at=NOW(3) " +
            "WHERE id=#{id} AND user_id=#{userId} AND is_deleted=FALSE")
    int softDelete(@Param("id") Long id, @Param("userId") Long userId);
}

