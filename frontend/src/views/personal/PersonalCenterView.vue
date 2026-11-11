<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import http, { dataOf } from '../../api/http'
import { useAuthStore } from '../../stores/auth'
import type { DataRow } from '../../types'

const auth = useAuthStore()

const active = ref('history')
const rows = ref<DataRow[]>([])
const total = ref(0)
const page = ref(1)
const size = ref(20)
const stats = ref<DataRow>({})
const profile = ref<DataRow>({})
const historyStart = ref('')
const historyEnd = ref('')

const get = (o: DataRow, c: string, s: string) => o[c] ?? o[s] ?? 0

async function loadTab(reset = false) {
  if (reset) page.value = 1

  let url = '/me/behaviors'
  const params: DataRow = { page: page.value, size: size.value }
  if (active.value === 'history') {
    url = '/me/history'
    params.start = historyStart.value || undefined
    params.end = historyEnd.value || undefined
  } else if (active.value === 'likes') {
    url = '/me/likes'
  } else if (active.value === 'favorites') {
    url = '/me/favorites'
  } else if (active.value === 'shares') {
    params.type = 'SHARE'
  } else if (active.value === 'comments') {
    params.type = 'COMMENT'
  }

  // /me/history、/me/likes、/me/favorites 返回数组，
  // /me/behaviors 返回 PageResult，这里统一成「列表 + 总数」两种形态。
  const data = dataOf<any>(await http.get(url, { params }))
  if (Array.isArray(data)) {
    rows.value = data
    total.value = data.length
  } else {
    rows.value = data.items
    total.value = data.total
  }
}

async function saveProfile() {
  await http.put('/me/profile', {
    nickname: profile.value.nickname,
    bio: profile.value.bio
  })
  if (auth.user) {
    auth.user.nickname = profile.value.nickname
    localStorage.setItem('user', JSON.stringify(auth.user))
  }
  ElMessage.success('资料已保存')
}

onMounted(async () => {
  profile.value = dataOf(await http.get('/auth/me'))
  stats.value = dataOf(await http.get(`/users/${auth.user!.userId}/statistics`))
  await loadTab()
})
</script>

<template>
  <div class="page">
    <h1 class="page-title">个人中心</h1>
    <p class="page-subtitle">查看你的观看、互动记录与主动行为统计。</p>

    <div class="summary-grid">
      <div><b>{{ get(stats, 'activePlayCount', 'active_play_count') }}</b><span>播放</span></div>
      <div><b>{{ get(stats, 'activeLikeCount', 'active_like_count') }}</b><span>当前点赞</span></div>
      <div><b>{{ get(stats, 'activeFavoriteCount', 'active_favorite_count') }}</b><span>当前收藏</span></div>
      <div><b>{{ get(stats, 'activeShareCount', 'active_share_count') }}</b><span>累计转发</span></div>
      <div><b>{{ get(stats, 'activeCommentCount', 'active_comment_count') }}</b><span>有效评论</span></div>
    </div>

    <div class="panel" style="margin-top: 24px">
      <h2>个人资料</h2>
      <el-form label-position="top" style="max-width: 600px">
        <el-form-item label="昵称">
          <el-input v-model="profile.nickname" maxlength="50" />
        </el-form-item>
        <el-form-item label="简介">
          <el-input v-model="profile.bio" type="textarea" maxlength="255" />
        </el-form-item>
        <el-button type="primary" color="#244d40" @click="saveProfile">保存资料</el-button>
      </el-form>
    </div>

    <div class="panel" style="margin-top: 24px">
      <el-tabs v-model="active" @tab-change="loadTab">
        <el-tab-pane label="观看历史" name="history" />
        <el-tab-pane label="当前点赞" name="likes" />
        <el-tab-pane label="当前收藏" name="favorites" />
        <el-tab-pane label="转发记录" name="shares" />
        <el-tab-pane label="评论记录" name="comments" />
        <el-tab-pane label="全部行为" name="behaviors" />
      </el-tabs>

      <div v-if="active === 'history'" class="history-filters">
        <el-date-picker v-model="historyStart" value-format="YYYY-MM-DDTHH:mm:ss" type="datetime" placeholder="开始时间" />
        <el-date-picker v-model="historyEnd" value-format="YYYY-MM-DDTHH:mm:ss" type="datetime" placeholder="结束时间" />
        <el-button @click="loadTab(true)">筛选</el-button>
      </div>

      <el-table :data="rows" stripe>
        <el-table-column prop="behavior_type" label="行为" width="130">
          <template #default="s">{{ s.row.behaviorType || s.row.behavior_type || active }}</template>
        </el-table-column>
        <el-table-column label="视频">
          <template #default="s">
            <router-link
              v-if="s.row.videoId || s.row.video_id || s.row.id"
              :to="`/videos/${s.row.videoId || s.row.video_id || s.row.id}`">
              {{ s.row.videoTitle || s.row.video_title || s.row.title }}
            </router-link>
          </template>
        </el-table-column>
        <el-table-column label="作者" width="140">
          <template #default="s">{{ s.row.authorName || s.row.author_name || s.row.targetName || s.row.target_name }}</template>
        </el-table-column>
        <el-table-column label="时间" width="190">
          <template #default="s">
            {{ s.row.occurredAt || s.row.occurred_at || s.row.startedAt || s.row.started_at
              || s.row.likedAt || s.row.liked_at || s.row.favoritedAt || s.row.favorited_at }}
          </template>
        </el-table-column>
        <el-table-column label="内容">
          <template #default="s">{{ s.row.detail }}</template>
        </el-table-column>
      </el-table>

      <div v-if="!rows.length" class="empty">暂无记录</div>

      <el-pagination
        v-if="total > size"
        style="justify-content: center; margin-top: 20px"
        background
        layout="total, prev, pager, next"
        :total="total"
        :page-size="size"
        v-model:current-page="page"
        @current-change="loadTab()" />
    </div>
  </div>
</template>

<style scoped>
.summary-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 14px }
.summary-grid div { background: #244d40; color: #fff; border-radius: 14px; padding: 22px }
.summary-grid b,
.summary-grid span { display: block }
.summary-grid b { font-size: 27px }
.summary-grid span { opacity: .7; margin-top: 6px; font-size: 13px }
.history-filters { display: flex; gap: 10px; flex-wrap: wrap; margin: 4px 0 18px }
@media (max-width: 700px) {
  .summary-grid { grid-template-columns: repeat(2, 1fr) }
}
</style>
