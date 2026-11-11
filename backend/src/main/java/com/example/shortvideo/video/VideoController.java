package com.example.shortvideo.video;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.common.api.PageResult;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.SecurityUtils;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@RestController
@RequiredArgsConstructor
public class VideoController {
    private final VideoService videoService;
    private final VideoMapper videoMapper;

    @GetMapping("/api/categories")
    public ApiResponse<List<Map<String, Object>>> categories() {
        return ApiResponse.ok(videoMapper.categories());
    }

    @GetMapping("/api/videos")
    public ApiResponse<PageResult<Map<String, Object>>> list(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Long authorId,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "12") int size) {
        return ApiResponse.ok(videoService.list(keyword, authorId, categoryId, page, size, false));
    }

    @GetMapping("/api/me/videos")
    public ApiResponse<PageResult<Map<String, Object>>> myVideos(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(videoService.list(null, SecurityUtils.currentUserId(), null, page, size, true));
    }

    @GetMapping("/api/videos/{id}")
    public ApiResponse<Map<String, Object>> detail(@PathVariable Long id) {
        return ApiResponse.ok(videoService.detail(id, false));
    }

    @PostMapping("/api/videos")
    public ApiResponse<Long> upload(@RequestParam String title,
                                    @RequestParam(defaultValue = "") String description,
                                    @RequestParam Long categoryId,
                                    @RequestPart("file") MultipartFile file) {
        return ApiResponse.ok(videoService.upload(title, description, categoryId, file));
    }

    @PutMapping("/api/videos/{id}")
    public ApiResponse<Void> update(@PathVariable Long id, @RequestBody UpdateVideoRequest request) {
        videoService.update(id, request.getCategoryId(), request.getTitle(), request.getDescription());
        return ApiResponse.ok();
    }

    @DeleteMapping("/api/videos/{id}")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        videoService.delete(id);
        return ApiResponse.ok();
    }

    @GetMapping("/api/admin/videos/{id}/audit")
    public ApiResponse<List<Map<String, Object>>> audit(@PathVariable Long id) {
        if (!SecurityUtils.isAdmin()) throw BusinessException.forbidden("仅管理员可以查看审计记录");
        return ApiResponse.ok(videoMapper.auditLog(id));
    }

    @Data
    public static class UpdateVideoRequest {
        private Long categoryId;
        private String title;
        private String description;
    }
}

