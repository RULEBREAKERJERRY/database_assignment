package com.example.shortvideo.comment;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.common.api.PageResult;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class CommentController {
    private final CommentService service;

    @GetMapping("/videos/{videoId}/comments")
    public ApiResponse<PageResult<Map<String, Object>>> list(@PathVariable Long videoId,
                                                             @RequestParam(defaultValue = "1") int page,
                                                             @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(service.list(videoId, page, size));
    }

    @PostMapping("/videos/{videoId}/comments")
    public ApiResponse<Long> create(@PathVariable Long videoId, @RequestBody CommentRequest request) {
        return ApiResponse.ok(service.create(videoId, request.getContent()));
    }

    @DeleteMapping("/comments/{id}")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ApiResponse.ok();
    }

    @Data
    public static class CommentRequest {
        private String content;
    }
}

