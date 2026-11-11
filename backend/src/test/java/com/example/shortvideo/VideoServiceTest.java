package com.example.shortvideo;

import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.UserPrincipal;
import com.example.shortvideo.video.VideoMapper;
import com.example.shortvideo.video.VideoService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VideoServiceTest {
    @Mock private VideoMapper videoMapper;
    private VideoService service;

    @BeforeEach
    void setUp() {
        service = new VideoService(videoMapper);
        UserPrincipal principal = new UserPrincipal(7L, "tester", "hash", "USER", true);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    /**
     * 越权删除：SQL 里带 author_id = 当前用户，命中 0 行即为越权。
     * 这里刻意不先查一次「视频属于谁」再判断——那样会多一次查询，
     * 而且在并发下仍有 TOCTOU 窗口；用带条件的 UPDATE 一次完成校验与写入。
     */
    @Test
    void deletingOthersVideoIsForbidden() {
        when(videoMapper.softDeleteOwned(42L, 7L)).thenReturn(0);

        BusinessException ex = assertThrows(BusinessException.class, () -> service.delete(42L));

        assertEquals(HttpStatus.FORBIDDEN, ex.getStatus());
        assertEquals("无权删除该视频或视频已删除", ex.getMessage());
    }
}
