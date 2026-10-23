<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import http, { dataOf } from '../../api/http'
import type { DataRow, PageResult } from '../../types'

const videos = ref<DataRow[]>([])
const categories = ref<DataRow[]>([])
const total = ref(0)
const loading = ref(false)
const filters = reactive({ keyword: '', categoryId: undefined as number | undefined, page: 1, size: 12 })
const value = (row: DataRow, camel: string, snake: string) => row[camel] ?? row[snake] ?? 0

async function load() {
  loading.value = true
  try {
    const result = dataOf<PageResult<DataRow>>(await http.get('/videos', { params: filters }))
    videos.value = result.items
    total.value = result.total
  } finally { loading.value = false }
}

onMounted(async () => {
  categories.value = dataOf<DataRow[]>(await http.get('/categories'))
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
      <el-input v-model="filters.keyword" placeholder="搜索视频标题" clearable style="width:280px" @keyup.enter="filters.page=1;load()" />
      <el-select v-model="filters.categoryId" placeholder="全部分类" clearable style="width:160px" @change="filters.page=1;load()">
        <el-option v-for="item in categories" :key="item.id" :label="item.name" :value="item.id" />
      </el-select>
      <el-button type="primary" color="#d45e34" @click="filters.page=1;load()">查询</el-button>
    </div>
    <div v-loading="loading" class="video-grid">
      <router-link v-for="video in videos" :key="video.id" :to="`/videos/${video.id}`" class="video-card">
        <div class="video-thumb">▶</div>
        <div class="video-card-body">
          <h3>{{ video.title }}</h3>
          <div class="muted">{{ value(video,'authorName','author_name') }} · {{ value(video,'categoryName','category_name') }}</div>
          <div class="stat-row">
            <span>▶ {{ value(video,'playCount','play_count') }}</span>
            <span>♥ {{ value(video,'currentLikeCount','current_like_count') }}</span>
            <span>评论 {{ value(video,'validCommentCount','valid_comment_count') }}</span>
          </div>
        </div>
      </router-link>
    </div>
    <div v-if="!loading && !videos.length" class="empty">还没有符合条件的视频</div>
    <el-pagination v-if="total>filters.size" style="justify-content:center;margin-top:30px" background layout="prev, pager, next"
      :total="total" :page-size="filters.size" v-model:current-page="filters.page" @current-change="load" />
  </div>
</template>

