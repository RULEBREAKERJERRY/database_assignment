<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import http, { dataOf } from '../../api/http'
import { useAuthStore } from '../../stores/auth'
import type { DataRow } from '../../types'

const auth=useAuthStore();const rows=ref<DataRow[]>([]);const filters=reactive({userId:undefined as number|undefined,videoId:undefined as number|undefined,type:'',start:'',end:''})
const types=['PLAY','LIKE','UNLIKE','FAVORITE','UNFAVORITE','SHARE','COMMENT','COMMENT_DELETE','FOLLOW','UNFOLLOW']
async function load(){const url=auth.isAdmin?'/admin/behaviors':'/me/behaviors';const params={...filters,start:filters.start||undefined,end:filters.end||undefined};rows.value=dataOf(await http.get(url,{params}))}
onMounted(load)
</script>

<template>
  <div class="page"><h1 class="page-title">行为明细查询</h1><p class="page-subtitle">{{auth.isAdmin?'管理员可查询全平台行为。':'你只能查询自己的完整行为历史。'}}</p>
    <div class="panel"><div class="filters"><el-input-number v-if="auth.isAdmin" v-model="filters.userId" placeholder="用户 ID" :min="1"/><el-input-number v-model="filters.videoId" placeholder="视频 ID" :min="1"/><el-select v-model="filters.type" clearable placeholder="行为类型" style="width:180px"><el-option v-for="t in types" :key="t" :label="t" :value="t"/></el-select><el-date-picker v-model="filters.start" value-format="YYYY-MM-DDTHH:mm:ss" type="datetime" placeholder="开始时间"/><el-date-picker v-model="filters.end" value-format="YYYY-MM-DDTHH:mm:ss" type="datetime" placeholder="结束时间"/><el-button type="primary" color="#d45e34" @click="load">查询</el-button></div>
      <el-table :data="rows" stripe><el-table-column label="行为" width="145"><template #default="s">{{s.row.behaviorType||s.row.behavior_type}}</template></el-table-column><el-table-column v-if="auth.isAdmin" label="用户" width="140"><template #default="s">{{s.row.actorName||s.row.actor_name}} ({{s.row.actorUserId||s.row.actor_user_id}})</template></el-table-column><el-table-column label="视频"><template #default="s"><router-link v-if="s.row.videoId||s.row.video_id" :to="`/videos/${s.row.videoId||s.row.video_id}`">{{s.row.videoTitle||s.row.video_title}}</router-link><span v-else>—</span></template></el-table-column><el-table-column label="对象/作者" width="150"><template #default="s">{{s.row.targetName||s.row.target_name}}</template></el-table-column><el-table-column label="内容"><template #default="s">{{s.row.detail||'—'}}</template></el-table-column><el-table-column label="发生时间" width="190"><template #default="s">{{s.row.occurredAt||s.row.occurred_at}}</template></el-table-column></el-table><div v-if="!rows.length" class="empty">暂无符合条件的行为</div>
    </div>
  </div>
</template>

