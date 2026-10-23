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
}

