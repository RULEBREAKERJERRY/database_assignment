package com.example.shortvideo;

import com.example.shortvideo.comment.CommentMapper;
import com.example.shortvideo.comment.CommentService;
import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.security.UserPrincipal;
import com.example.shortvideo.video.Video;
import com.example.shortvideo.video.VideoMapper;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CommentServiceTest {
    @Mock private CommentMapper commentMapper;
    @Mock private VideoMapper videoMapper;
    private CommentService service;

    @BeforeEach
    void setUp() {
        service = new CommentService(commentMapper, videoMapper);
        UserPrincipal principal = new UserPrincipal(7L, "tester", "hash", "USER", true);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    /**
     * 空评论在进数据库之前就应该被拒。
     * 表上的 ck_comment_content 只能拦住纯空白写入，抛的是 SQL 异常；
     * 这里验证业务层给出的是 400 + 可读提示，并且根本不去锁视频行。
     */
    @Test
    void blankContentIsRejectedBeforeTouchingDatabase() {
        BusinessException ex = assertThrows(BusinessException.class, () -> service.create(9L, "   \n  "));

        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertEquals("评论内容不能为空", ex.getMessage());
        verifyNoInteractions(videoMapper);
        verify(commentMapper, never()).insert(any());
    }

    /** 评论已删除或不属于本人时，softDelete 影响行数为 0，应返回 403 而不是静默成功。 */
    @Test
    void deletingOthersCommentIsForbidden() {
        when(commentMapper.softDelete(11L, 7L)).thenReturn(0);

        BusinessException ex = assertThrows(BusinessException.class, () -> service.delete(11L));

        assertEquals(HttpStatus.FORBIDDEN, ex.getStatus());
    }
}
