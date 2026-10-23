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

    public static boolean isAdmin() {
        return "ADMIN".equals(current().getRole());
    }
}

