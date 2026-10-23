package com.example.shortvideo.follow;

import org.apache.ibatis.annotations.*;

@Mapper
public interface FollowMapper {
    @Insert("INSERT IGNORE INTO follow_relations(follower_id, followed_id) VALUES(#{followerId}, #{followedId})")
    int follow(@Param("followerId") Long followerId, @Param("followedId") Long followedId);

    @Delete("DELETE FROM follow_relations WHERE follower_id=#{followerId} AND followed_id=#{followedId}")
    int unfollow(@Param("followerId") Long followerId, @Param("followedId") Long followedId);

    @Insert("INSERT INTO follow_events(follower_id, followed_id, event_type, request_id) " +
            "VALUES(#{followerId}, #{followedId}, #{type}, #{requestId})")
    int event(@Param("followerId") Long followerId, @Param("followedId") Long followedId,
              @Param("type") String type, @Param("requestId") String requestId);

    @Select("SELECT COUNT(*) FROM follow_relations WHERE follower_id=#{followerId} AND followed_id=#{followedId}")
    int isFollowing(@Param("followerId") Long followerId, @Param("followedId") Long followedId);
}

