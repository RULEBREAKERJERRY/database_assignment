<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import http, { dataOf } from '../../api/http'
import { useAuthStore } from '../../stores/auth'

const mode = ref<'login'|'register'>('login')
const busy = ref(false)
const form = reactive({ username: '', password: '', nickname: '', bio: '' })
const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

async function submit() {
  busy.value = true
  try {
    const response = mode.value === 'login'
      ? await http.post('/auth/login', { username: form.username, password: form.password })
      : await http.post('/auth/register', form)
    const result = dataOf<any>(response)
    auth.save(result.token, result)
    ElMessage.success(mode.value === 'login' ? '登录成功' : '注册成功')
    router.push(String(route.query.redirect || '/'))
  } finally { busy.value = false }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-visual">
        <div><span>◉</span><h1>让每一次互动<br>都有迹可循</h1><p>短视频数据管理系统</p></div>
      </div>
      <div class="auth-form">
        <el-segmented v-model="mode" :options="[{label:'登录',value:'login'},{label:'注册',value:'register'}]" />
        <h2>{{ mode === 'login' ? '欢迎回来' : '创建新账号' }}</h2>
        <el-form label-position="top" @submit.prevent="submit">
          <el-form-item label="账号"><el-input v-model="form.username" maxlength="50" /></el-form-item>
          <el-form-item v-if="mode==='register'" label="昵称"><el-input v-model="form.nickname" maxlength="50" /></el-form-item>
          <el-form-item label="密码"><el-input v-model="form.password" type="password" show-password /></el-form-item>
          <el-form-item v-if="mode==='register'" label="个人简介"><el-input v-model="form.bio" type="textarea" maxlength="255" /></el-form-item>
          <el-button type="primary" color="#d45e34" native-type="submit" :loading="busy" style="width:100%;margin-top:8px">
            {{ mode === 'login' ? '登录' : '注册并登录' }}
          </el-button>
        </el-form>
        <p class="muted" style="margin-top:20px">演示账号：admin / alice / bob，密码均为 password</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.auth-page {
  min-height: calc(100vh - 110px);
  display: grid;
  place-items: center;
  padding: 40px 20px;
}
.auth-card {
  width: min(850px, 100%);
  display: grid;
  grid-template-columns: 1fr 1fr;
  background: #fff;
  border-radius: 22px;
  overflow: hidden;
  box-shadow: 0 24px 80px rgba(32, 44, 38, .13);
}
.auth-visual {
  padding: 55px;
  background: linear-gradient(145deg, #173d31, #254f41);
  color: #fff;
  display: flex;
  align-items: flex-end;
  min-height: 520px;
}
.auth-visual span { font-size: 54px; color: #ed8a5d }
.auth-visual h1 { font-size: 36px; line-height: 1.3 }
.auth-visual p { opacity: .7 }
.auth-form { padding: 52px }
.auth-form h2 { font-size: 28px; margin: 35px 0 24px }
@media (max-width: 700px) {
  .auth-card { grid-template-columns: 1fr }
  .auth-visual { display: none }
  .auth-form { padding: 34px }
}
</style>

