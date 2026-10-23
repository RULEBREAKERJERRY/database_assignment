package com.example.shortvideo.auth;

import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.JwtTokenProvider;
import com.example.shortvideo.security.UserPrincipal;
import com.example.shortvideo.user.User;
import com.example.shortvideo.user.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider tokenProvider;

    public AuthDtos.LoginResponse register(AuthDtos.RegisterRequest request) {
        if (userMapper.findByUsername(request.getUsername().trim()) != null) {
            throw BusinessException.badRequest("账号已存在");
        }
        User user = new User();
        user.setUsername(request.getUsername().trim());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setNickname(request.getNickname().trim());
        user.setBio(request.getBio() == null ? "" : request.getBio().trim());
        userMapper.insert(user);
        return loginInternal(user.getUsername(), request.getPassword());
    }

    public AuthDtos.LoginResponse login(AuthDtos.LoginRequest request) {
        return loginInternal(request.getUsername().trim(), request.getPassword());
    }

    private AuthDtos.LoginResponse loginInternal(String username, String password) {
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(username, password));
            UserPrincipal principal = (UserPrincipal) authentication.getPrincipal();
            User user = userMapper.findById(principal.getId());
            return new AuthDtos.LoginResponse(tokenProvider.createToken(principal), user.getId(),
                    user.getUsername(), user.getNickname(), user.getRole());
        } catch (Exception ex) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "账号或密码错误");
        }
    }
}

