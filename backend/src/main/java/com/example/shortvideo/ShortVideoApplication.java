package com.example.shortvideo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@EnableTransactionManagement
@SpringBootApplication
public class ShortVideoApplication {
    public static void main(String[] args) {
        SpringApplication.run(ShortVideoApplication.class, args);
    }
}

