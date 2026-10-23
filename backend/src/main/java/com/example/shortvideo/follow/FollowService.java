package com.example.shortvideo.follow;

import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.SecurityUtils;
import com.example.shortvideo.user.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
@RequiredArgsConstructor
public class FollowService {
    private final FollowMapper followMapper;
    private final UserMapper userMapper;

    @Transactional
    public void follow(Long targetId, String requestId) {
        Long userId = SecurityUtils.currentUserId();
        validate(userId, targetId, requestId);
        if (followMapper.follow(userId, targetId) == 1) {
            followMapper.event(userId, targetId, "FOLLOW", requestId.trim());
        }
    }

    @Transactional
    public void unfollow(Long targetId, String requestId) {
        Long userId = SecurityUtils.currentUserId();
        validate(userId, targetId, requestId);
        if (followMapper.unfollow(userId, targetId) == 1) {
            followMapper.event(userId, targetId, "UNFOLLOW", requestId.trim());
        }
    }

    private void validate(Long userId, Long targetId, String requestId) {
        if (userId.equals(targetId)) throw BusinessException.badRequest("不能关注自己");
        if (userMapper.findById(targetId) == null) throw BusinessException.notFound("目标用户不存在");
        if (!StringUtils.hasText(requestId) || requestId.length() > 64) {
            throw BusinessException.badRequest("请求编号不能为空且不能超过64个字符");
        }
    }
}

