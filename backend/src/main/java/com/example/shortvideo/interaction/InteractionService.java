package com.example.shortvideo.interaction;

import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.SecurityUtils;
import com.example.shortvideo.video.Video;
import com.example.shortvideo.video.VideoMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.LinkedHashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class InteractionService {
    private final InteractionMapper interactionMapper;
    private final VideoMapper videoMapper;

    @Transactional
    public boolean play(Long videoId, String requestId) {
        checkRequestId(requestId);
        assertInteractive(videoId);
        return interactionMapper.addPlay(SecurityUtils.currentUserId(), videoId, requestId.trim()) == 1;
    }

    @Transactional
    public boolean share(Long videoId, String requestId) {
        checkRequestId(requestId);
        assertInteractive(videoId);
        return interactionMapper.addShare(SecurityUtils.currentUserId(), videoId, requestId.trim()) == 1;
    }

    @Transactional
    public void like(Long videoId, String requestId) {
        checkRequestId(requestId);
        assertInteractive(videoId);
        Long userId = SecurityUtils.currentUserId();
        if (interactionMapper.addLike(userId, videoId) == 1) {
            interactionMapper.addLikeEvent(userId, videoId, "LIKE", requestId.trim());
        }
    }

    @Transactional
    public void unlike(Long videoId, String requestId) {
        checkRequestId(requestId);
        assertInteractive(videoId);
        Long userId = SecurityUtils.currentUserId();
        if (interactionMapper.removeLike(userId, videoId) == 1) {
            interactionMapper.addLikeEvent(userId, videoId, "UNLIKE", requestId.trim());
        }
    }

    @Transactional
    public void favorite(Long videoId, String requestId) {
        checkRequestId(requestId);
        assertInteractive(videoId);
        Long userId = SecurityUtils.currentUserId();
        if (interactionMapper.addFavorite(userId, videoId) == 1) {
            interactionMapper.addFavoriteEvent(userId, videoId, "FAVORITE", requestId.trim());
        }
    }

    @Transactional
    public void unfavorite(Long videoId, String requestId) {
        checkRequestId(requestId);
        assertInteractive(videoId);
        Long userId = SecurityUtils.currentUserId();
        if (interactionMapper.removeFavorite(userId, videoId) == 1) {
            interactionMapper.addFavoriteEvent(userId, videoId, "UNFAVORITE", requestId.trim());
        }
    }

    public Map<String, Boolean> currentState(Long videoId) {
        Long userId = SecurityUtils.currentUserId();
        Map<String, Boolean> state = new LinkedHashMap<>();
        state.put("liked", interactionMapper.hasLiked(userId, videoId) > 0);
        state.put("favorited", interactionMapper.hasFavorited(userId, videoId) > 0);
        return state;
    }

    private Video assertInteractive(Long videoId) {
        Video video = videoMapper.lockById(videoId);
        if (video == null || !"PUBLISHED".equals(video.getStatus())) {
            throw BusinessException.badRequest("视频不存在或已删除，不能新增互动");
        }
        return video;
    }

    private void checkRequestId(String requestId) {
        if (!StringUtils.hasText(requestId) || requestId.length() > 64) {
            throw BusinessException.badRequest("请求编号不能为空且不能超过64个字符");
        }
    }
}

