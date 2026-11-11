<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import http, { dataOf } from '../../api/http'
import { useAuthStore } from '../../stores/auth'
import type { DataRow, PageResult } from '../../types'

const auth = useAuthStore()

const rows = ref<DataRow[]>([])
const total = ref(0)
const loading = ref(false)

const filters = reactive({
  userId: undefined as number | undefined,
  videoId: undefined as number | undefined,
  type: '',
  start: '',
  end: '',
  page: 1,
  size: 20
})

const types = [
  'PLAY', 'LIKE', 'UNLIKE', 'FAVORITE', 'UNFAVORITE', 'SHARE',
  'COMMENT', 'COMMENT_DELETE', 'FOLLOW', 'UNFOLLOW'
]

async function load() {
  loading.value = true
  try {
    const url = auth.isAdmin ? '/admin/behaviors' : '/me/behaviors'
    const params = {
      ...filters,
      start: filters.start || undefined,
      end: filters.end || undefined
    }
    const result = dataOf<PageResult<DataRow>>(await http.get(url, { params }))
    rows.value = result.items
    total.value = result.total
  } finally {
    loading.value = false
  }
}

/** 条件变化时回到第一页，否则会停在一个已不存在的页码上。 */
function search() {
  filters.page = 1
  load()
}

function onSizeChange() {
  filters.page = 1
  load()
}

onMounted(load)
</script>

<template>
  <div class="page">
    <h1 class="page-title">行为明细查询</h1>
    <p class="page-subtitle">
      {{ auth.isAdmin ? '管理员可查询全平台行为。' : '你只能查询自己的完整行为历史。' }}
    </p>

    <div class="panel">
      <div class="filters">
        <el-input-number
          v-if="auth.isAdmin" v-model="filters.userId"
          placeholder="用户 ID" :min="1" :controls="false" style="width:120px" />
        <el-input-number
          v-model="filters.videoId"
          placeholder="视频 ID" :min="1" :controls="false" style="width:120px" />
        <el-select v-model="filters.type" clearable placeholder="行为类型" style="width:180px">
          <el-option v-for="t in types" :key="t" :label="t" :value="t" />
        </el-select>
        <el-date-picker
          v-model="filters.start" value-format="YYYY-MM-DDTHH:mm:ss"
          type="datetime" placeholder="开始时间" style="width:190px" />
        <el-date-picker
          v-model="filters.end" value-format="YYYY-MM-DDTHH:mm:ss"
          type="datetime" placeholder="结束时间" style="width:190px" />
        <el-button type="primary" color="#d45e34" @click="search">查询</el-button>
      </div>

      <el-table v-loading="loading" :data="rows" stripe>
        <el-table-column label="行为" width="170">
          <template #default="s">{{ s.row.behaviorType || s.row.behavior_type }}</template>
        </el-table-column>
        <el-table-column v-if="auth.isAdmin" label="用户" width="150">
          <template #default="s">
            {{ s.row.actorName || s.row.actor_name }} ({{ s.row.actorUserId || s.row.actor_user_id }})
          </template>
        </el-table-column>
        <el-table-column label="视频">
          <template #default="s">
            <router-link v-if="s.row.videoId || s.row.video_id" :to="`/videos/${s.row.videoId || s.row.video_id}`">
              {{ s.row.videoTitle || s.row.video_title }}
            </router-link>
            <span v-else>—</span>
          </template>
        </el-table-column>
        <el-table-column label="对象/作者" width="150">
          <template #default="s">{{ s.row.targetName || s.row.target_name }}</template>
        </el-table-column>
        <el-table-column label="内容">
          <template #default="s">{{ s.row.detail || '—' }}</template>
        </el-table-column>
        <el-table-column label="发生时间" width="190">
          <template #default="s">{{ s.row.occurredAt || s.row.occurred_at }}</template>
        </el-table-column>
      </el-table>

      <div v-if="!loading && !rows.length" class="empty">暂无符合条件的行为</div>

      <el-pagination
        v-if="total > 0"
        style="justify-content:center;margin-top:22px"
        background
        layout="total, sizes, prev, pager, next, jumper"
        :page-sizes="[10, 20, 50, 100]"
        :total="total"
        v-model:current-page="filters.page"
        v-model:page-size="filters.size"
        @current-change="load"
        @size-change="onSizeChange" />
    </div>
  </div>
</template>
