package com.example.shortvideo.auth;

import lombok.AllArgsConstructor;
import lombok.Data;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Size;

public final class AuthDtos {
    private AuthDtos() {}

    @Data
    public static class RegisterRequest {
        @NotBlank(message = "账号不能为空")
        @Size(min = 3, max = 50, message = "账号长度应为3至50个字符")
        private String username;
        @NotBlank(message = "密码不能为空")
        @Size(min = 6, max = 72, message = "密码长度应为6至72个字符")
        private String password;
        @NotBlank(message = "昵称不能为空")
        @Size(max = 50, message = "昵称不能超过50个字符")
        private String nickname;
        @Size(max = 255, message = "简介不能超过255个字符")
        private String bio = "";
    }

    @Data
    public static class LoginRequest {
        @NotBlank(message = "账号不能为空")
        private String username;
        @NotBlank(message = "密码不能为空")
        private String password;
    }

    @Data
    @AllArgsConstructor
    public static class LoginResponse {
        private String token;
        private Long userId;
        private String username;
        private String nickname;
        private String role;
    }
}

