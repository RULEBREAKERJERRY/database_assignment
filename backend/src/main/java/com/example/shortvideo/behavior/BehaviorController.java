package com.example.shortvideo.behavior;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class BehaviorController {
    private final BehaviorMapper mapper;

    @GetMapping("/me/behaviors")
    public ApiResponse<List<Map<String, Object>>> mine(
            @RequestParam(required = false) Long videoId,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "50") int size) {
        return ApiResponse.ok(query(SecurityUtils.currentUserId(), videoId, type, start, end, page, size));
    }

    @GetMapping("/admin/behaviors")
    public ApiResponse<List<Map<String, Object>>> admin(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long videoId,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "50") int size) {
        if (!SecurityUtils.isAdmin()) throw BusinessException.forbidden("仅管理员可以查询全局行为");
        return ApiResponse.ok(query(userId, videoId, type, start, end, page, size));
    }

    private List<Map<String, Object>> query(Long userId, Long videoId, String type,
                                             LocalDateTime start, LocalDateTime end,
                                             int page, int size) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 100);
        return mapper.query(userId, videoId, type, start, end,
                (safePage - 1) * safeSize, safeSize);
    }
}

