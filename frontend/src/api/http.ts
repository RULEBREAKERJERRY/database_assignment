import axios from 'axios'
import { ElMessage } from 'element-plus'
import type { ApiResponse } from '../types'

const http = axios.create({ baseURL: '/api', timeout: 20000 })

http.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

http.interceptors.response.use(
  response => response,
  error => {
    const message = error.response?.data?.message || '请求失败，请检查服务是否启动'
    ElMessage.error(message)
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      localStorage.removeItem('user')
    }
    return Promise.reject(error)
  }
)

export function dataOf<T>(response: { data: ApiResponse<T> }): T {
  return response.data.data
}

export function requestId(): string {
  return crypto.randomUUID()
}

export default http

