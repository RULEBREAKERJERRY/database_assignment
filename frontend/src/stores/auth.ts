import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

export interface SessionUser {
  userId: number
  username: string
  nickname: string
  role: 'USER' | 'ADMIN'
}

export const useAuthStore = defineStore('auth', () => {
  const saved = localStorage.getItem('user')
  const user = ref<SessionUser | null>(saved ? JSON.parse(saved) : null)
  const loggedIn = computed(() => !!user.value && !!localStorage.getItem('token'))
  const isAdmin = computed(() => user.value?.role === 'ADMIN')

  function save(token: string, nextUser: SessionUser) {
    localStorage.setItem('token', token)
    localStorage.setItem('user', JSON.stringify(nextUser))
    user.value = nextUser
  }

  function logout() {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    user.value = null
  }

  return { user, loggedIn, isAdmin, save, logout }
})

