package com.example.shortvideo.user;

import com.example.shortvideo.common.api.ApiResponse;
import com.example.shortvideo.security.SecurityUtils;
import com.example.shortvideo.common.exception.BusinessException;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Size;
import java.util.List;
import java.util.Map;

@RestController
@RequiredArgsConstructor
public class UserController {
    private final UserMapper userMapper;

    @GetMapping("/api/users/{id}")
    public ApiResponse<Map<String, Object>> profile(@PathVariable Long id) {
        Map<String, Object> profile = userMapper.profile(id);
        if (profile == null) throw BusinessException.notFound("用户不存在");
        return ApiResponse.ok(profile);
    }

    @PutMapping("/api/me/profile")
    public ApiResponse<Void> update(@Valid @RequestBody ProfileRequest request) {
        userMapper.updateProfile(SecurityUtils.currentUserId(), request.getNickname().trim(),
                request.getBio() == null ? "" : request.getBio().trim());
        return ApiResponse.ok();
    }

    @GetMapping("/api/users")
    public ApiResponse<List<Map<String, Object>>> search(
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "20") int limit) {
        String kw = keyword == null ? null : keyword.trim();
        return ApiResponse.ok(userMapper.search(kw, Math.min(Math.max(limit, 1), 50)));
    }

    @GetMapping("/api/users/{id}/following")
    public ApiResponse<List<Map<String, Object>>> following(@PathVariable Long id) {
        return ApiResponse.ok(userMapper.following(id));
    }

    @GetMapping("/api/users/{id}/followers")
    public ApiResponse<List<Map<String, Object>>> followers(@PathVariable Long id) {
        return ApiResponse.ok(userMapper.followers(id));
    }

    @Data
    public static class ProfileRequest {
        @NotBlank(message = "昵称不能为空")
        @Size(max = 50, message = "昵称不能超过50个字符")
        private String nickname;
        @Size(max = 255, message = "简介不能超过255个字符")
        private String bio;
    }
}

