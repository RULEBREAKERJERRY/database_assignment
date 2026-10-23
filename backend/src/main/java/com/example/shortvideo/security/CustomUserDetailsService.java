package com.example.shortvideo.security;

import com.example.shortvideo.user.User;
import com.example.shortvideo.user.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {
    private final UserMapper userMapper;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userMapper.findByUsername(username);
        if (user == null) throw new UsernameNotFoundException("用户不存在");
        return new UserPrincipal(user.getId(), user.getUsername(), user.getPasswordHash(),
                user.getRole(), "ACTIVE".equals(user.getStatus()));
    }

    public UserPrincipal loadById(Long id) {
        User user = userMapper.findById(id);
        if (user == null) throw new UsernameNotFoundException("用户不存在");
        return new UserPrincipal(user.getId(), user.getUsername(), user.getPasswordHash(),
                user.getRole(), "ACTIVE".equals(user.getStatus()));
    }
}

