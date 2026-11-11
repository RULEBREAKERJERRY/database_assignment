<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import http, { dataOf } from '../../api/http'
import type { DataRow, PageResult } from '../../types'

const route = useRoute()
const router = useRouter()

const videos = ref<DataRow[]>([])
const categories = ref<DataRow[]>([])
const authorOptions = ref<DataRow[]>([])
const total = ref(0)
const loading = ref(false)
const authorLoading = ref(false)

const filters = reactive({
  keyword: '',
  categoryId: undefined as number | undefined,
  authorId: undefined as number | undefined,
  page: 1,
  size: 12
})

const value = (row: DataRow, camel: string, snake: string) => row[camel] ?? row[snake] ?? 0

async function load() {
  loading.value = true
  try {
    const params = {
      keyword: filters.keyword || undefined,
      categoryId: filters.categoryId,
      authorId: filters.authorId,
      page: filters.page,
      size: filters.size
    }
    const result = dataOf<PageResult<DataRow>>(await http.get('/videos', { params }))
    videos.value = result.items
    total.value = result.total
  } finally {
    loading.value = false
  }
}

/** 作者下拉是远程检索：默认给 20 个按粉丝数排序的用户，输入时按昵称/用户名模糊匹配。 */
async function searchAuthors(keyword = '') {
  authorLoading.value = true
  try {
    authorOptions.value = dataOf<DataRow[]>(
      await http.get('/users', { params: { keyword: keyword || undefined, limit: 20 } })
    )
  } finally {
    authorLoading.value = false
  }
}

function onAuthorChange(id?: number) {
  filters.page = 1
  // 把作者条件写进地址栏，刷新或分享链接时筛选状态不丢。
  const query = { ...route.query }
  if (id) query.authorId = String(id)
  else delete query.authorId
  router.replace({ query })
  load()
}

function search() {
  filters.page = 1
  load()
}

onMounted(async () => {
  categories.value = dataOf<DataRow[]>(await http.get('/categories'))
  await searchAuthors()

  const fromQuery = Number(route.query.authorId)
  if (fromQuery) {
    filters.authorId = fromQuery
    if (!authorOptions.value.some(u => u.id === fromQuery)) {
      // 从个人主页跳过来时作者可能不在前 20 名里，单独取一次保证下拉能显示昵称。
      try {
        const user = dataOf<DataRow>(await http.get(`/users/${fromQuery}`))
        authorOptions.value = [{ id: user.id, nickname: user.nickname, username: user.username }, ...authorOptions.value]
      } catch {
        filters.authorId = undefined
      }
    }
  }
  await load()
})
</script>

<template>
  <div class="page">
    <section style="padding: 38px 0 30px">
      <p class="muted" style="letter-spacing:.18em;color:#c4542c">DISCOVER STORIES</p>
      <h1 class="page-title" style="font-size:42px">发现此刻，记录生活</h1>
      <p class="page-subtitle">浏览作品，也让每一次播放和互动都有迹可循。</p>
    </section>

    <div class="filters">
      <el-input
        v-model="filters.keyword" placeholder="搜索视频标题" clearable style="width:240px"
        @keyup.enter="search" />
      <el-select
        v-model="filters.categoryId" placeholder="全部分类" clearable style="width:150px"
        @change="search">
        <el-option v-for="item in categories" :key="item.id" :label="item.name" :value="item.id" />
      </el-select>
      <el-select
        v-model="filters.authorId" placeholder="全部作者" clearable filterable remote
        :remote-method="searchAuthors" :loading="authorLoading"
        style="width:200px" @change="onAuthorChange">
        <el-option
          v-for="item in authorOptions" :key="item.id"
          :label="`${item.nickname} (@${item.username})`" :value="item.id" />
      </el-select>
      <el-button type="primary" color="#d45e34" @click="search">查询</el-button>
      <span class="muted" style="font-size:13px">共 {{ total }} 个作品</span>
    </div>

    <div v-loading="loading" class="video-grid">
      <router-link v-for="video in videos" :key="video.id" :to="`/videos/${video.id}`" class="video-card">
        <div class="video-thumb">▶</div>
        <div class="video-card-body">
          <h3>{{ video.title }}</h3>
          <div class="muted">{{ value(video, 'authorName', 'author_name') }} · {{ value(video, 'categoryName', 'category_name') }}</div>
          <div class="stat-row">
            <span>▶ {{ value(video, 'playCount', 'play_count') }}</span>
            <span>♥ {{ value(video, 'currentLikeCount', 'current_like_count') }}</span>
            <span>评论 {{ value(video, 'validCommentCount', 'valid_comment_count') }}</span>
          </div>
        </div>
      </router-link>
    </div>
    <div v-if="!loading && !videos.length" class="empty">还没有符合条件的视频</div>

    <el-pagination
      v-if="total > filters.size"
      style="justify-content:center;margin-top:30px" background
      layout="prev, pager, next"
      :total="total" :page-size="filters.size"
      v-model:current-page="filters.page" @current-change="load" />
  </div>
</template>
