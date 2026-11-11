package com.example.shortvideo;

import com.example.shortvideo.common.exception.BusinessException;
import com.example.shortvideo.interaction.InteractionMapper;
import com.example.shortvideo.interaction.InteractionService;
import com.example.shortvideo.security.UserPrincipal;
import com.example.shortvideo.video.Video;
import com.example.shortvideo.video.VideoMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class InteractionServiceTest {
    @Mock private InteractionMapper interactionMapper;
    @Mock private VideoMapper videoMapper;
    private InteractionService service;

    @BeforeEach
    void setUp() {
        service = new InteractionService(interactionMapper, videoMapper);
        UserPrincipal principal = new UserPrincipal(7L, "tester", "hash", "USER", true);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void deletedVideoCannotReceiveNewPlay() {
        Video video = new Video();
        video.setId(9L);
        video.setStatus("DELETED");
        when(videoMapper.shareLockById(9L)).thenReturn(video);

        assertThrows(BusinessException.class, () -> service.play(9L, "request-1"));
        verifyNoInteractions(interactionMapper);
    }

    @Test
    void repeatedLikeDoesNotAppendAnotherHistoryEvent() {
        Video video = new Video();
        video.setId(9L);
        video.setStatus("PUBLISHED");
        when(videoMapper.shareLockById(9L)).thenReturn(video);
        when(interactionMapper.addLike(7L, 9L)).thenReturn(0);

        service.like(9L, "request-2");

        verify(interactionMapper, never()).addLikeEvent(anyLong(), anyLong(), anyString(), anyString());
    }
}

