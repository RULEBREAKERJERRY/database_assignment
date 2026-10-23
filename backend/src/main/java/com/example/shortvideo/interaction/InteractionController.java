package com.example.shortvideo.interaction;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class InteractionController {
    private final InteractionService service;
    private final InteractionMapper mapper;

    @PostMapping("/videos/{videoId}/play")
    public ApiResponse<Boolean> play(@PathVariable Long videoId, @RequestHeader("Idempotency-Key") String requestId) {
        return ApiResponse.ok(service.play(videoId, requestId));
    }

    @PostMapping("/videos/{videoId}/share")
    public ApiResponse<Boolean> share(@PathVariable Long videoId, @RequestHeader("Idempotency-Key") String requestId) {
        return ApiResponse.ok(service.share(videoId, requestId));
    }

    @PostMapping("/videos/{videoId}/like")
    public ApiResponse<Void> like(@PathVariable Long videoId, @RequestHeader("Idempotency-Key") String requestId) {
        service.like(videoId, requestId);
        return ApiResponse.ok();
    }

    @DeleteMapping("/videos/{videoId}/like")
    public ApiResponse<Void> unlike(@PathVariable Long videoId, @RequestHeader("Idempotency-Key") String requestId) {
        service.unlike(videoId, requestId);
        return ApiResponse.ok();
    }

    @PostMapping("/videos/{videoId}/favorite")
    public ApiResponse<Void> favorite(@PathVariable Long videoId, @RequestHeader("Idempotency-Key") String requestId) {
        service.favorite(videoId, requestId);
        return ApiResponse.ok();
    }

    @DeleteMapping("/videos/{videoId}/favorite")
    public ApiResponse<Void> unfavorite(@PathVariable Long videoId, @RequestHeader("Idempotency-Key") String requestId) {
        service.unfavorite(videoId, requestId);
        return ApiResponse.ok();
    }

    @GetMapping("/videos/{videoId}/interaction-state")
    public ApiResponse<Map<String, Boolean>> state(@PathVariable Long videoId) {
        return ApiResponse.ok(service.currentState(videoId));
    }

    @GetMapping("/me/likes")
    public ApiResponse<List<Map<String, Object>>> likes() {
        return ApiResponse.ok(mapper.currentLikes(SecurityUtils.currentUserId()));
    }

    @GetMapping("/me/favorites")
    public ApiResponse<List<Map<String, Object>>> favorites() {
        return ApiResponse.ok(mapper.currentFavorites(SecurityUtils.currentUserId()));
    }

    @GetMapping("/me/history")
    public ApiResponse<List<Map<String, Object>>> history(@RequestParam(defaultValue = "1") int page,
                                                          @RequestParam(defaultValue = "20") int size,
                                                          @RequestParam(required = false)
                                                          @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
                                                          @RequestParam(required = false)
                                                          @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 100);
        return ApiResponse.ok(mapper.playHistory(SecurityUtils.currentUserId(), start, end,
                (safePage - 1) * safeSize, safeSize));
    }
}

