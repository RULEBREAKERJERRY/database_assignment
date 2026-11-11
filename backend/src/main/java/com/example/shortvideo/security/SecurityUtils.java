package com.example.shortvideo.security;

import com.example.shortvideo.common.exception.BusinessException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class SecurityUtils {
    private SecurityUtils() {}

    public static UserPrincipal current() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof UserPrincipal)) {
            throw BusinessException.forbidden("请先登录");
        }
        return (UserPrincipal) authentication.getPrincipal();
    }

    public static Long currentUserId() {
        return current().getId();
    }

    /**
     * 匿名可访问的接口（如 GET /api/videos/{id}/interaction-state）用它取当前用户。
     * 返回 null 表示未登录，由调用方决定是返回默认值还是拒绝，避免直接抛 403 变成 500。
     */
    public static Long currentUserIdOrNull() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof UserPrincipal)) {
            return null;
        }
        return ((UserPrincipal) authentication.getPrincipal()).getId();
    }

    public static boolean isAdmin() {
        return "ADMIN".equals(current().getRole());
    }
}

