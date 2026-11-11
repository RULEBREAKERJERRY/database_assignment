<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import http, { dataOf, requestId } from '../../api/http'
import { useAuthStore } from '../../stores/auth'
import type { DataRow, PageResult } from '../../types'

const route = useRoute()
const auth = useAuthStore()

const profile = ref<DataRow>({})
const stats = ref<DataRow>({})
const videos = ref<DataRow[]>([])
const followingList = ref<DataRow[]>([])
const followerList = ref<DataRow[]>([])
const activeTab = ref('works')
const isFollowing = ref(false)
const followBusy = ref(false)

const userId = computed(() => Number(route.params.id))
const isSelf = computed(() => auth.user?.userId === userId.value)
const value = (row: DataRow, camel: string, snake: string) => row[camel] ?? row[snake] ?? 0
/** 后端返回 ISO 时间（带 T 和毫秒），页面上只展示到秒。 */
const fmt = (t?: string) => (t ? String(t).replace('T', ' ').slice(0, 19) : '')

/** 关系列表只在切到对应页签时拉取，避免每次进主页都多两次查询。 */
const loaded = { following: false, followers: false }

async function loadRelations(which: 'following' | 'followers') {
  if (loaded[which]) return
  loaded[which] = true
  const rows = dataOf<DataRow[]>(await http.get(`/users/${userId.value}/${which}`))
  if (which === 'following') followingList.value = rows
  else followerList.value = rows
}

function onTabChange(name: string) {
  if (name === 'following' || name === 'followers') loadRelations(name)
}

async function load() {
  loaded.following = false
  loaded.followers = false
  followingList.value = []
  followerList.value = []
  activeTab.value = 'works'

  profile.value = dataOf(await http.get(`/users/${userId.value}`))
  stats.value = dataOf(await http.get(`/users/${userId.value}/statistics`))
  videos.value = dataOf<PageResult<DataRow>>(
    await http.get('/videos', { params: { authorId: userId.value, size: 50 } })
  ).items

  isFollowing.value = false
  if (auth.loggedIn && !isSelf.value) {
    const state = dataOf<{ following: boolean }>(await http.get(`/follows/${userId.value}/state`))
    isFollowing.value = state.following
  }
}

async function toggleFollow() {
  if (!auth.loggedIn) {
    ElMessage.warning('请先登录')
    return
  }
  followBusy.value = true
  try {
    const config = { headers: { 'Idempotency-Key': requestId() } }
    if (isFollowing.value) await http.delete(`/follows/${userId.value}`, config)
    else await http.post(`/follows/${userId.value}`, null, config)
    isFollowing.value = !isFollowing.value
    // 粉丝数、粉丝列表都会随关注状态变化，统一重新取一次，避免页面上的数字和列表打架。
    stats.value = dataOf(await http.get(`/users/${userId.value}/statistics`))
    if (loaded.followers) {
      followerList.value = dataOf<DataRow[]>(await http.get(`/users/${userId.value}/followers`))
    }
    ElMessage.success(isFollowing.value ? '已关注' : '已取消关注')
  } finally {
    followBusy.value = false
  }
}

onMounted(load)
watch(() => route.params.id, load)
</script>

<template>
  <div class="page">
    <div class="profile-hero panel">
      <div class="big-avatar">{{ String(profile.nickname || '?').slice(0, 1) }}</div>
      <div class="hero-main">
        <h1>{{ profile.nickname }}</h1>
        <p class="muted">@{{ profile.username }}</p>
        <p>{{ profile.bio || '这个人还没有填写简介。' }}</p>
      </div>
      <el-button
        v-if="auth.loggedIn && !isSelf"
        :type="isFollowing ? 'default' : 'primary'"
        :color="isFollowing ? undefined : '#d45e34'"
        :loading="followBusy"
        @click="toggleFollow">
        {{ isFollowing ? '已关注' : '关注' }}
      </el-button>
    </div>

    <div class="stats">
      <div class="clickable" @click="activeTab = 'followers'; loadRelations('followers')">
        <b>{{ value(stats, 'followerCount', 'follower_count') }}</b><span>粉丝</span>
      </div>
      <div class="clickable" @click="activeTab = 'following'; loadRelations('following')">
        <b>{{ value(stats, 'followingCount', 'following_count') }}</b><span>关注</span>
      </div>
      <div><b>{{ value(stats, 'receivedLikeCount', 'received_like_count') }}</b><span>获赞</span></div>
      <div><b>{{ value(stats, 'receivedPlayCount', 'received_play_count') }}</b><span>播放</span></div>
      <div><b>{{ value(stats, 'receivedFavoriteCount', 'received_favorite_count') }}</b><span>收藏</span></div>
      <div><b>{{ value(stats, 'receivedShareCount', 'received_share_count') }}</b><span>转发</span></div>
      <div><b>{{ value(stats, 'receivedCommentCount', 'received_comment_count') }}</b><span>评论</span></div>
    </div>

    <el-tabs v-model="activeTab" class="relation-tabs" @tab-change="onTabChange">
      <el-tab-pane label="公开作品" name="works">
        <div class="video-grid">
          <router-link v-for="v in videos" :key="v.id" :to="`/videos/${v.id}`" class="video-card">
            <div class="video-thumb">▶</div>
            <div class="video-card-body">
              <h3>{{ v.title }}</h3>
              <span class="muted">{{ fmt(v.publishedAt || v.published_at) }}</span>
            </div>
          </router-link>
        </div>
        <div v-if="!videos.length" class="empty">暂无公开作品</div>
      </el-tab-pane>

      <el-tab-pane :label="`关注 ${value(stats, 'followingCount', 'following_count')}`" name="following">
        <div class="user-list">
          <router-link v-for="u in followingList" :key="u.id" :to="`/users/${u.id}`" class="user-row">
            <div class="mini-avatar">{{ String(u.nickname || '?').slice(0, 1) }}</div>
            <div class="user-info">
              <strong>{{ u.nickname }}</strong>
              <span class="muted">@{{ u.username }}</span>
              <span class="bio">{{ u.bio || '这个人还没有填写简介。' }}</span>
            </div>
            <span class="muted time">{{ fmt(u.followedAt || u.followed_at) }}</span>
          </router-link>
        </div>
        <div v-if="!followingList.length" class="empty">还没有关注任何人</div>
      </el-tab-pane>

      <el-tab-pane :label="`粉丝 ${value(stats, 'followerCount', 'follower_count')}`" name="followers">
        <div class="user-list">
          <router-link v-for="u in followerList" :key="u.id" :to="`/users/${u.id}`" class="user-row">
            <div class="mini-avatar">{{ String(u.nickname || '?').slice(0, 1) }}</div>
            <div class="user-info">
              <strong>{{ u.nickname }}</strong>
              <span class="muted">@{{ u.username }}</span>
              <span class="bio">{{ u.bio || '这个人还没有填写简介。' }}</span>
            </div>
            <span class="muted time">{{ fmt(u.followedAt || u.followed_at) }}</span>
          </router-link>
        </div>
        <div v-if="!followerList.length" class="empty">还没有粉丝</div>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<style scoped>
.profile-hero{display:flex;gap:24px;align-items:center;background:linear-gradient(120deg,#fff,#f0eee5)}
.hero-main{flex:1}
.big-avatar{width:100px;height:100px;border-radius:50%;background:#244d40;color:#fff;display:grid;place-items:center;font-size:40px}
.profile-hero h1{margin:0}
.stats{display:grid;grid-template-columns:repeat(7,1fr);gap:10px;margin-top:20px}
.stats div{background:#fff;border:1px solid #ebe7de;border-radius:12px;padding:18px;text-align:center}
.stats div.clickable{cursor:pointer;transition:border-color .15s}
.stats div.clickable:hover{border-color:#d45e34}
.stats b,.stats span{display:block}
.stats b{font-size:22px;color:#244d40}
.stats span{font-size:12px;color:#777;margin-top:5px}
.relation-tabs{margin-top:28px}
.user-list{display:flex;flex-direction:column;gap:10px}
.user-row{display:flex;align-items:center;gap:14px;background:#fff;border:1px solid #ebe7de;border-radius:12px;padding:14px 18px;color:inherit;text-decoration:none}
.user-row:hover{border-color:#d45e34}
.mini-avatar{width:44px;height:44px;border-radius:50%;background:#244d40;color:#fff;display:grid;place-items:center;font-size:18px;flex:none}
.user-info{display:flex;flex-direction:column;gap:2px;min-width:0;flex:1}
.user-info .bio{font-size:13px;color:#555;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.time{flex:none;font-size:12px;margin-left:auto}
@media(max-width:760px){.stats{grid-template-columns:repeat(3,1fr)}}
</style>
