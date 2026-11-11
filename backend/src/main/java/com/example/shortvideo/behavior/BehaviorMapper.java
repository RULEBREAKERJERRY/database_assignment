package com.example.shortvideo.behavior;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Mapper
public interface BehaviorMapper {
    List<Map<String, Object>> query(@Param("userId") Long userId,
                                    @Param("videoId") Long videoId,
                                    @Param("type") String type,
                                    @Param("start") LocalDateTime start,
                                    @Param("end") LocalDateTime end,
                                    @Param("offset") int offset,
                                    @Param("size") int size);

    /**
     * 与 query 使用同一段 UNION ALL 数据源与同一组筛选条件，仅聚合为总数。
     * 拆成两条语句而不是用 SQL_CALC_FOUND_ROWS，是为了让分页在数据量大时仍然只扫一遍索引。
     */
    long count(@Param("userId") Long userId,
               @Param("videoId") Long videoId,
               @Param("type") String type,
               @Param("start") LocalDateTime start,
               @Param("end") LocalDateTime end);
}
