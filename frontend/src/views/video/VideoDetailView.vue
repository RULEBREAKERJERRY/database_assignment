<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import http, { dataOf, requestId } from '../../api/http'
import { useAuthStore } from '../../stores/auth'
import type { DataRow, PageResult } from '../../types'

const route = useRoute()
const auth = useAuthStore()
const videoId = Number(route.params.id)
const video = ref<DataRow>({})
const comments = ref<DataRow[]>([])
const state = ref({ liked:false, favorited:false })
const following = ref(false)
const content = ref('')
const value = (camel:string,snake:string) => video.value[camel] ?? video.value[snake] ?? 0
const authorId = computed(()=>Number(value('authorId','author_id')))

async function load() {
  video.value = dataOf(await http.get(`/videos/${videoId}`))
  comments.value = dataOf<PageResult<DataRow>>(await http.get(`/videos/${videoId}/comments`)).items
  if (auth.loggedIn) {
    state.value = dataOf(await http.get(`/videos/${videoId}/interaction-state`))
    if (authorId.value !== auth.user?.userId) {
      following.value = dataOf<any>(await http.get(`/follows/${authorId.value}/state`)).following
    }
  }
}

async function onPlay() {
  if (!auth.loggedIn) return
  await http.post(`/videos/${videoId}/play`, null, { headers:{'Idempotency-Key':requestId()} })
}
async function toggleLike() {
  const config = { headers:{'Idempotency-Key':requestId()} }
  if (state.value.liked) await http.delete(`/videos/${videoId}/like`, config)
  else await http.post(`/videos/${videoId}/like`, null, config)
  state.value.liked=!state.value.liked; await loadStats()
}
async function toggleFavorite() {
  const config = { headers:{'Idempotency-Key':requestId()} }
  if (state.value.favorited) await http.delete(`/videos/${videoId}/favorite`, config)
  else await http.post(`/videos/${videoId}/favorite`, null, config)
  state.value.favorited=!state.value.favorited; await loadStats()
}
async function share() {
  await http.post(`/videos/${videoId}/share`, null, { headers:{'Idempotency-Key':requestId()} })
  ElMessage.success('已加入我的转发记录'); await loadStats()
}
async function toggleFollow() {
  const config = { headers:{'Idempotency-Key':requestId()} }
  if (following.value) await http.delete(`/follows/${authorId.value}`, config)
  else await http.post(`/follows/${authorId.value}`, null, config)
  following.value=!following.value
}
async function addComment() {
  if (!content.value.trim()) return
  await http.post(`/videos/${videoId}/comments`, {content:content.value})
  content.value=''; ElMessage.success('评论成功'); await loadComments(); await loadStats()
}
async function deleteComment(id:number) {
  await http.delete(`/comments/${id}`); await loadComments(); await loadStats()
}
async function loadComments(){ comments.value=dataOf<PageResult<DataRow>>(await http.get(`/videos/${videoId}/comments`)).items }
async function loadStats(){ Object.assign(video.value,dataOf(await http.get(`/videos/${videoId}/statistics`))) }
function requireLogin(){ if(!auth.loggedIn){ ElMessage.warning('请先登录'); return false } return true }

onMounted(load)
</script>

<template>
  <div class="page detail-page">
    <div class="player-wrap"><video v-if="video.filePath || video.file_path" :src="video.filePath || video.file_path" controls @play="onPlay" /></div>
    <div class="detail-grid">
      <section>
        <p class="muted">{{ value('categoryName','category_name') }}</p>
        <h1>{{ video.title }}</h1>
        <p class="description">{{ video.description || '作者没有填写作品简介。' }}</p>
        <div class="actions">
          <el-button :type="state.liked?'danger':'default'" @click="requireLogin()&&toggleLike()">♥ {{ value('currentLikeCount','current_like_count') }}</el-button>
          <el-button :type="state.favorited?'warning':'default'" @click="requireLogin()&&toggleFavorite()">★ {{ value('currentFavoriteCount','current_favorite_count') }}</el-button>
          <el-button @click="requireLogin()&&share()">↗ 转发 {{ value('shareCount','share_count') }}</el-button>
          <span class="muted">播放 {{ value('playCount','play_count') }} · 观众 {{ value('uniqueViewerCount','unique_viewer_count') }}</span>
        </div>
        <div class="comments panel">
          <h2>评论 <small>{{ value('validCommentCount','valid_comment_count') }}</small></h2>
          <div v-if="auth.loggedIn" class="comment-input"><el-input v-model="content" maxlength="1000" placeholder="写下你的评论…" @keyup.enter="addComment"/><el-button type="primary" color="#d45e34" @click="addComment">发表</el-button></div>
          <div v-for="item in comments" :key="item.id" class="comment-item">
            <div><b>{{ item.authorName || item.author_name }}</b><p>{{ item.content }}</p><span class="muted">{{ item.createdAt || item.created_at }}</span></div>
            <el-button v-if="item.userId===auth.user?.userId || item.user_id===auth.user?.userId" text type="danger" @click="deleteComment(item.id)">删除</el-button>
          </div>
          <div v-if="!comments.length" class="empty">还没有评论</div>
        </div>
      </section>
      <aside class="panel author-card">
        <div class="avatar">{{ String(value('authorName','author_name')).slice(0,1) }}</div>
        <router-link :to="`/users/${authorId}`"><h3>{{ value('authorName','author_name') }}</h3></router-link>
        <el-button v-if="auth.loggedIn && authorId!==auth.user?.userId" :type="following?'default':'primary'" color="#244d40" @click="toggleFollow">{{ following?'取消关注':'关注作者' }}</el-button>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.detail-page{max-width:1050px}.player-wrap{background:#0d1311;border-radius:18px;overflow:hidden;aspect-ratio:16/9;box-shadow:0 18px 50px rgba(10,20,16,.18)}video{width:100%;height:100%;display:block}.detail-grid{display:grid;grid-template-columns:1fr 250px;gap:24px;margin-top:28px}h1{font-size:30px;margin:4px 0 12px}.description{color:#62625c;line-height:1.7}.actions{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:22px 0 32px}.comments h2 small{color:#999;font-weight:400}.comment-input{display:flex;gap:10px;margin:20px 0}.comment-item{display:flex;justify-content:space-between;border-top:1px solid #eeeae2;padding:18px 0}.comment-item p{margin:8px 0}.author-card{text-align:center;height:max-content}.avatar{width:74px;height:74px;border-radius:50%;background:#d8e4de;color:#244d40;display:grid;place-items:center;font-size:28px;font-weight:700;margin:0 auto}@media(max-width:760px){.detail-grid{grid-template-columns:1fr}.author-card{grid-row:1}}
</style>

