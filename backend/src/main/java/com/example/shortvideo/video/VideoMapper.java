package com.example.shortvideo.video;

import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface VideoMapper {
    List<Map<String, Object>> list(@Param("keyword") String keyword,
                                   @Param("authorId") Long authorId,
                                   @Param("categoryId") Long categoryId,
                                   @Param("includeDeleted") boolean includeDeleted,
                                   @Param("offset") int offset,
                                   @Param("size") int size);

    long count(@Param("keyword") String keyword,
               @Param("authorId") Long authorId,
               @Param("categoryId") Long categoryId,
               @Param("includeDeleted") boolean includeDeleted);

    Map<String, Object> detail(@Param("id") Long id, @Param("includeDeleted") boolean includeDeleted);

    @Select("SELECT * FROM videos WHERE id=#{id}")
    Video findById(Long id);

    @Select("SELECT * FROM videos WHERE id=#{id} FOR UPDATE")
    Video lockById(Long id);

    /**
     * 互动路径用共享锁：多个点赞/播放可以同时拿到 S 锁，不会互相排队；
     * 而删除走 UPDATE 需要 X 锁，必须等在途互动全部提交。
     * 这样既保留了「删除后不能新增互动」的正确性，又不把热门视频串行化。
     */
    @Select("SELECT * FROM videos WHERE id=#{id} FOR SHARE")
    Video shareLockById(Long id);

    @Insert("INSERT INTO videos(author_id, category_id, title, description, file_path) " +
            "VALUES(#{authorId}, #{categoryId}, #{title}, #{description}, #{filePath})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Video video);

    @Update("UPDATE videos SET category_id=#{categoryId}, title=#{title}, description=#{description} " +
            "WHERE id=#{id} AND author_id=#{authorId} AND status='PUBLISHED'")
    int updateOwned(Video video);

    @Update("UPDATE videos SET status='DELETED', deleted_at=NOW(3) " +
            "WHERE id=#{id} AND author_id=#{authorId} AND status='PUBLISHED'")
    int softDeleteOwned(@Param("id") Long id, @Param("authorId") Long authorId);

    @Select("SELECT id, name, sort_order FROM video_categories ORDER BY sort_order, id")
    List<Map<String, Object>> categories();

    /**
     * 审计记录由数据库触发器 trg_videos_audit_status 写入（见 database/10_triggers.sql），
     * 应用层只负责读，不参与写，避免「应用忘了记」的情况。
     */
    @Select("SELECT id, video_id, action, old_status, new_status, changed_at " +
            "FROM video_audit WHERE video_id=#{id} ORDER BY id DESC")
    List<Map<String, Object>> auditLog(Long id);

    @Select("SELECT COUNT(*) FROM video_categories WHERE id=#{id}")
    int categoryExists(Long id);
}

