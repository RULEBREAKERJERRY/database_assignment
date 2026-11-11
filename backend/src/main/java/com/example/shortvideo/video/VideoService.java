package com.example.shortvideo.video;

import com.example.shortvideo.common.api.PageResult;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class VideoService {
    private final VideoMapper videoMapper;

    @Value("${app.storage.video-directory}")
    private String videoDirectory;
    @Value("${app.storage.public-prefix}")
    private String publicPrefix;

    public PageResult<Map<String, Object>> list(String keyword, Long authorId, Long categoryId,
                                                 int page, int size, boolean includeDeleted) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 50);
        String normalized = StringUtils.hasText(keyword) ? keyword.trim() : null;
        return new PageResult<>(videoMapper.list(normalized, authorId, categoryId, includeDeleted,
                (safePage - 1) * safeSize, safeSize),
                videoMapper.count(normalized, authorId, categoryId, includeDeleted), safePage, safeSize);
    }

    public Map<String, Object> detail(Long id, boolean includeDeleted) {
        Map<String, Object> result = videoMapper.detail(id, includeDeleted);
        if (result == null) throw BusinessException.notFound("视频不存在或已删除");
        return result;
    }

    @Transactional
    public Long upload(String title, String description, Long categoryId, MultipartFile file) {
        validateMetadata(title, description, categoryId);
        if (file == null || file.isEmpty()) throw BusinessException.badRequest("请选择视频文件");
        // 浏览器上传通常带 video/* 类型；部分客户端（curl、移动端、某些采集工具）会退化为
        // application/octet-stream，此时以扩展名白名单作为补充判断，避免误拒合法视频。
        String contentType = file.getContentType();
        String original = file.getOriginalFilename();
        String extension = original != null && original.lastIndexOf('.') >= 0
                ? original.substring(original.lastIndexOf('.')).toLowerCase() : ".mp4";
        boolean extensionAllowed = extension.matches("\\.(mp4|webm|mov|m4v|ogg)");
        boolean contentTypeAllowed = contentType == null
                || contentType.startsWith("video/")
                || ("application/octet-stream".equals(contentType) && extensionAllowed);
        if (!contentTypeAllowed) {
            throw BusinessException.badRequest("只能上传视频文件");
        }
        if (!extensionAllowed) extension = ".mp4";
        String storedName = UUID.randomUUID() + extension;
        Path directory = Paths.get(videoDirectory).toAbsolutePath().normalize();
        Path target = directory.resolve(storedName).normalize();
        if (!target.startsWith(directory)) throw BusinessException.badRequest("非法文件名");

        try {
            Files.createDirectories(directory);
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException ex) {
            throw new IllegalStateException("视频文件保存失败", ex);
        }

        Video video = new Video();
        video.setAuthorId(SecurityUtils.currentUserId());
        video.setCategoryId(categoryId);
        video.setTitle(title.trim());
        video.setDescription(description == null ? "" : description.trim());
        video.setFilePath(publicPrefix + storedName);
        try {
            videoMapper.insert(video);
        } catch (RuntimeException ex) {
            try {
                Files.deleteIfExists(target);
            } catch (IOException ignored) {
                // 数据库异常优先返回；遗留文件可由运维清理。
            }
            throw ex;
        }
        return video.getId();
    }

    @Transactional
    public void update(Long id, Long categoryId, String title, String description) {
        validateMetadata(title, description, categoryId);
        Video video = new Video();
        video.setId(id);
        video.setAuthorId(SecurityUtils.currentUserId());
        video.setCategoryId(categoryId);
        video.setTitle(title.trim());
        video.setDescription(description == null ? "" : description.trim());
        if (videoMapper.updateOwned(video) == 0) throw BusinessException.forbidden("无权修改该视频或视频已删除");
    }

    @Transactional
    public void delete(Long id) {
        if (videoMapper.softDeleteOwned(id, SecurityUtils.currentUserId()) == 0) {
            throw BusinessException.forbidden("无权删除该视频或视频已删除");
        }
    }

    private void validateMetadata(String title, String description, Long categoryId) {
        if (!StringUtils.hasText(title)) throw BusinessException.badRequest("标题不能为空");
        if (title.trim().length() > 120) throw BusinessException.badRequest("标题不能超过120个字符");
        if (description != null && description.trim().length() > 1000) {
            throw BusinessException.badRequest("简介不能超过1000个字符");
        }
        if (categoryId == null || videoMapper.categoryExists(categoryId) == 0) {
            throw BusinessException.badRequest("视频分类不存在");
        }
    }
}

