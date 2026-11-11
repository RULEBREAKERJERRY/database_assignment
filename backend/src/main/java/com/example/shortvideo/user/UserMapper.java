package com.example.shortvideo.user;

import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface UserMapper {
    @Select("SELECT * FROM users WHERE username = #{username}")
    User findByUsername(String username);

    @Select("SELECT * FROM users WHERE id = #{id}")
    User findById(Long id);

    @Insert("INSERT INTO users(username, password_hash, nickname, bio) " +
            "VALUES(#{username}, #{passwordHash}, #{nickname}, #{bio})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(User user);

    @Update("UPDATE users SET nickname = #{nickname}, bio = #{bio} WHERE id = #{id}")
    int updateProfile(@Param("id") Long id, @Param("nickname") String nickname, @Param("bio") String bio);

    @Select("SELECT u.id, u.username, u.nickname, u.bio, u.avatar_url, u.created_at, " +
            "(SELECT COUNT(*) FROM follow_relations f WHERE f.followed_id=u.id) follower_count, " +
            "(SELECT COUNT(*) FROM follow_relations f WHERE f.follower_id=u.id) following_count " +
            "FROM users u WHERE u.id=#{id}")
    Map<String, Object> profile(Long id);

    @Select("SELECT u.id, u.username, u.nickname, u.bio, u.avatar_url, f.followed_at " +
            "FROM follow_relations f JOIN users u ON u.id=f.followed_id " +
            "WHERE f.follower_id=#{userId} ORDER BY f.followed_at DESC")
    List<Map<String, Object>> following(Long userId);

    @Select("SELECT u.id, u.username, u.nickname, u.bio, u.avatar_url, f.followed_at " +
            "FROM follow_relations f JOIN users u ON u.id=f.follower_id " +
            "WHERE f.followed_id=#{userId} ORDER BY f.followed_at DESC")
    List<Map<String, Object>> followers(Long userId);

    /**
     * 供首页「按作者筛选」下拉框检索用户：昵称或用户名模糊匹配，按粉丝数降序。
     * 关联子查询只取 COUNT，不 JOIN 出粉丝明细，避免检索框一次拉回大量行。
     */
    @Select("<script>" +
            "SELECT u.id, u.username, u.nickname, u.avatar_url, u.created_at, " +
            "       (SELECT COUNT(*) FROM follow_relations f WHERE f.followed_id = u.id) AS follower_count " +
            "FROM users u " +
            "<where>" +
            "  <if test=\"keyword != null and keyword != ''\">" +
            "    (u.nickname LIKE CONCAT('%', #{keyword}, '%') OR u.username LIKE CONCAT('%', #{keyword}, '%'))" +
            "  </if>" +
            "</where> " +
            "ORDER BY follower_count DESC, u.id ASC " +
            "LIMIT #{limit}" +
            "</script>")
    List<Map<String, Object>> search(@Param("keyword") String keyword, @Param("limit") int limit);
}

