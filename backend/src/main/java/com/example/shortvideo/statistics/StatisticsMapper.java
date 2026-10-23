package com.example.shortvideo.statistics;

import org.apache.ibatis.annotations.*;
import java.util.Map;

@Mapper
public interface StatisticsMapper {
    @Select("SELECT s.* FROM v_video_statistics s JOIN videos v ON v.id=s.video_id " +
            "WHERE s.video_id=#{videoId} AND v.status='PUBLISHED'")
    Map<String, Object> videoStatistics(Long videoId);

    Map<String, Object> userStatistics(Long userId);
}

