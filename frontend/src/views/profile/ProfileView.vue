<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import http, { dataOf } from '../../api/http'
import type { DataRow, PageResult } from '../../types'

const route=useRoute(); const profile=ref<DataRow>({}); const stats=ref<DataRow>({}); const videos=ref<DataRow[]>([])
const get=(o:DataRow,c:string,s:string)=>o[c]??o[s]??0
async function load(){const id=Number(route.params.id);profile.value=dataOf(await http.get(`/users/${id}`));stats.value=dataOf(await http.get(`/users/${id}/statistics`));videos.value=dataOf<PageResult<DataRow>>(await http.get('/videos',{params:{authorId:id,size:50}})).items}
onMounted(load);watch(()=>route.params.id,load)
</script>

<template>
  <div class="page">
    <div class="profile-hero panel">
      <div class="big-avatar">{{ String(profile.nickname||'?').slice(0,1) }}</div>
      <div><h1>{{ profile.nickname }}</h1><p class="muted">@{{ profile.username }}</p><p>{{ profile.bio || '这个人还没有填写简介。' }}</p></div>
    </div>
    <div class="stats">
      <div><b>{{ get(stats,'followerCount','follower_count') }}</b><span>粉丝</span></div><div><b>{{ get(stats,'followingCount','following_count') }}</b><span>关注</span></div>
      <div><b>{{ get(stats,'receivedLikeCount','received_like_count') }}</b><span>获赞</span></div><div><b>{{ get(stats,'receivedPlayCount','received_play_count') }}</b><span>播放</span></div>
      <div><b>{{ get(stats,'receivedFavoriteCount','received_favorite_count') }}</b><span>收藏</span></div><div><b>{{ get(stats,'receivedShareCount','received_share_count') }}</b><span>转发</span></div>
      <div><b>{{ get(stats,'receivedCommentCount','received_comment_count') }}</b><span>评论</span></div>
    </div>
    <h2 style="margin-top:38px">公开作品</h2>
    <div class="video-grid"><router-link v-for="v in videos" :key="v.id" :to="`/videos/${v.id}`" class="video-card"><div class="video-thumb">▶</div><div class="video-card-body"><h3>{{v.title}}</h3><span class="muted">{{v.publishedAt||v.published_at}}</span></div></router-link></div>
    <div v-if="!videos.length" class="empty">暂无公开作品</div>
  </div>
</template>

<style scoped>
.profile-hero{display:flex;gap:24px;align-items:center;background:linear-gradient(120deg,#fff,#f0eee5)}.big-avatar{width:100px;height:100px;border-radius:50%;background:#244d40;color:#fff;display:grid;place-items:center;font-size:40px}.profile-hero h1{margin:0}.stats{display:grid;grid-template-columns:repeat(7,1fr);gap:10px;margin-top:20px}.stats div{background:#fff;border:1px solid #ebe7de;border-radius:12px;padding:18px;text-align:center}.stats b,.stats span{display:block}.stats b{font-size:22px;color:#244d40}.stats span{font-size:12px;color:#777;margin-top:5px}@media(max-width:760px){.stats{grid-template-columns:repeat(3,1fr)}}
</style>

