package com.example.shortvideo.comment;

import com.example.shortvideo.common.api.PageResult;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.SecurityUtils;
import com.example.shortvideo.video.Video;
import com.example.shortvideo.video.VideoMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.Map;

@Service
@RequiredArgsConstructor
public class CommentService {
    private final CommentMapper commentMapper;
    private final VideoMapper videoMapper;

    public PageResult<Map<String, Object>> list(Long videoId, int page, int size) {
        Video video = videoMapper.findById(videoId);
        if (video == null || !"PUBLISHED".equals(video.getStatus())) {
            throw BusinessException.notFound("视频不存在或已删除");
        }
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 100);
        return new PageResult<>(commentMapper.list(videoId, (safePage - 1) * safeSize, safeSize),
                commentMapper.count(videoId), safePage, safeSize);
    }

    @Transactional
    public Long create(Long videoId, String content) {
        if (!StringUtils.hasText(content)) throw BusinessException.badRequest("评论内容不能为空");
        if (content.trim().length() > 1000) throw BusinessException.badRequest("评论不能超过1000个字符");
        Video video = videoMapper.shareLockById(videoId);
        if (video == null || !"PUBLISHED".equals(video.getStatus())) {
            throw BusinessException.badRequest("视频不存在或已删除，不能评论");
        }
        Comment comment = new Comment();
        comment.setUserId(SecurityUtils.currentUserId());
        comment.setVideoId(videoId);
        comment.setContent(content.trim());
        commentMapper.insert(comment);
        return comment.getId();
    }

    @Transactional
    public void delete(Long id) {
        if (commentMapper.softDelete(id, SecurityUtils.currentUserId()) == 0) {
            throw BusinessException.forbidden("无权删除该评论或评论已删除");
        }
    }
}

