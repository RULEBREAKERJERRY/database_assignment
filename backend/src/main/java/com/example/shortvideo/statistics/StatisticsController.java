package com.example.shortvideo.statistics;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.user.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class StatisticsController {
    private final StatisticsMapper mapper;
    private final UserMapper userMapper;

    @GetMapping("/videos/{videoId}/statistics")
    public ApiResponse<Map<String, Object>> video(@PathVariable Long videoId) {
        Map<String, Object> result = mapper.videoStatistics(videoId);
        if (result == null) throw BusinessException.notFound("视频不存在");
        return ApiResponse.ok(result);
    }

    @GetMapping("/users/{userId}/statistics")
    public ApiResponse<Map<String, Object>> user(@PathVariable Long userId) {
        if (userMapper.findById(userId) == null) throw BusinessException.notFound("用户不存在");
        return ApiResponse.ok(mapper.userStatistics(userId));
    }
}

