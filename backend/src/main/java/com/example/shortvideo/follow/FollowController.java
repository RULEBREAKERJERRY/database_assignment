package com.example.shortvideo.follow;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.Map;

@RestController
@RequestMapping("/api/follows")
@RequiredArgsConstructor
public class FollowController {
    private final FollowService service;
    private final FollowMapper mapper;

    @PostMapping("/{targetId}")
    public ApiResponse<Void> follow(@PathVariable Long targetId,
                                    @RequestHeader("Idempotency-Key") String requestId) {
        service.follow(targetId, requestId);
        return ApiResponse.ok();
    }

    @DeleteMapping("/{targetId}")
    public ApiResponse<Void> unfollow(@PathVariable Long targetId,
                                      @RequestHeader("Idempotency-Key") String requestId) {
        service.unfollow(targetId, requestId);
        return ApiResponse.ok();
    }

    @GetMapping("/{targetId}/state")
    public ApiResponse<Map<String, Boolean>> state(@PathVariable Long targetId) {
        return ApiResponse.ok(Collections.singletonMap("following",
                mapper.isFollowing(SecurityUtils.currentUserId(), targetId) > 0));
    }
}

