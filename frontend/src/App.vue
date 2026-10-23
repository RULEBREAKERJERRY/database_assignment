<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from './stores/auth'

const auth = useAuthStore()
const router = useRouter()

function logout() {
  auth.logout()
  router.push('/')
}
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <router-link to="/" class="brand"><span>◉</span> 光影集</router-link>
      <nav>
        <router-link to="/">发现</router-link>
        <template v-if="auth.loggedIn">
          <router-link to="/upload">发布</router-link>
          <router-link to="/works">作品</router-link>
          <router-link to="/center">个人中心</router-link>
          <router-link to="/behaviors">行为查询</router-link>
          <router-link v-if="auth.user" :to="`/users/${auth.user.userId}`">{{ auth.user.nickname }}</router-link>
          <button class="link-button" @click="logout">退出</button>
        </template>
        <router-link v-else to="/login">登录 / 注册</router-link>
      </nav>
    </header>
    <main><router-view /></main>
    <footer>数据库课程设计 · 短视频数据管理系统</footer>
  </div>
</template>

