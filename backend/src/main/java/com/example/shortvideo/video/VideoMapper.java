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

    @Select("SELECT COUNT(*) FROM video_categories WHERE id=#{id}")
    int categoryExists(Long id);
}

