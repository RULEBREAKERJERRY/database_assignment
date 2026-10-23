package com.example.shortvideo.video;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class Video {
    private Long id;
    private Long authorId;
    private Long categoryId;
    private String title;
    private String description;
    private String filePath;
    private String status;
    private LocalDateTime publishedAt;
    private LocalDateTime updatedAt;
    private LocalDateTime deletedAt;
}

