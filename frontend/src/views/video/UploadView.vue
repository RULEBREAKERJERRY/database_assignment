<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import http, { dataOf } from '../../api/http'
import type { DataRow } from '../../types'

const categories = ref<DataRow[]>([])
const file = ref<File>()
const busy = ref(false)
const form = reactive({ title: '', description: '', categoryId: undefined as number | undefined })
const router = useRouter()
onMounted(async()=> categories.value=dataOf(await http.get('/categories')))

async function submit() {
  if (!file.value || !form.title.trim() || !form.categoryId) return ElMessage.warning('请填写标题、分类并选择视频')
  const body = new FormData()
  body.append('title', form.title)
  body.append('description', form.description)
  body.append('categoryId', String(form.categoryId))
  body.append('file', file.value)
  busy.value = true
  try {
    const id = dataOf<number>(await http.post('/videos', body))
    ElMessage.success('视频发布成功')
    router.push(`/videos/${id}`)
  } finally { busy.value=false }
}
</script>

<template>
  <div class="page" style="max-width:800px">
    <h1 class="page-title">发布新作品</h1><p class="page-subtitle">上传成功后作品将直接公开发布。</p>
    <div class="panel">
      <el-form label-position="top">
        <el-form-item label="视频标题"><el-input v-model="form.title" maxlength="120" show-word-limit /></el-form-item>
        <el-form-item label="作品简介"><el-input v-model="form.description" type="textarea" :rows="4" maxlength="1000" show-word-limit /></el-form-item>
        <el-form-item label="分类"><el-select v-model="form.categoryId" style="width:100%"><el-option v-for="c in categories" :key="c.id" :label="c.name" :value="c.id" /></el-select></el-form-item>
        <el-form-item label="视频文件">
          <input type="file" accept="video/*" @change="file=($event.target as HTMLInputElement).files?.[0]" />
        </el-form-item>
        <el-button type="primary" color="#d45e34" :loading="busy" @click="submit">上传并发布</el-button>
      </el-form>
    </div>
  </div>
</template>

