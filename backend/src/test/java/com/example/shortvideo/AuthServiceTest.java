package com.example.shortvideo;

import com.example.shortvideo.auth.AuthDtos;
import com.example.shortvideo.auth.AuthService;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.user.User;
import com.example.shortvideo.user.UserMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {
    @Mock private UserMapper userMapper;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private AuthenticationManager authenticationManager;
    @Mock private com.example.shortvideo.security.JwtTokenProvider tokenProvider;

    /**
     * 注册重名必须被拦在写库之前。
     * 数据库层的 uk_users_username 是最后一道防线，但它抛的是 SQL 异常，
     * 接口层只能返回 500；业务层先查一次才能给出可读的 400 提示。
     */
    @Test
    void duplicateUsernameIsRejectedBeforeInsert() {
        AuthService service = new AuthService(userMapper, passwordEncoder, authenticationManager, tokenProvider);
        when(userMapper.findByUsername("alice")).thenReturn(new User());

        AuthDtos.RegisterRequest request = new AuthDtos.RegisterRequest();
        request.setUsername("alice");
        request.setPassword("password123");
        request.setNickname("重名账号");

        BusinessException ex = assertThrows(BusinessException.class, () -> service.register(request));

        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertEquals("账号已存在", ex.getMessage());
        verify(userMapper, never()).insert(any(User.class));
        verifyNoInteractions(passwordEncoder);
    }
}
