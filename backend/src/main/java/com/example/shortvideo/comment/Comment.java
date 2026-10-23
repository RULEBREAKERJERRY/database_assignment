package com.example.shortvideo.comment;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class Comment {
    private Long id;
    private Long userId;
    private Long videoId;
    private String content;
    private LocalDateTime createdAt;
    private Boolean deleted;
    private LocalDateTime deletedAt;
}

