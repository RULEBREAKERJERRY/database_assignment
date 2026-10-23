import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/home/HomeView.vue'
import LoginView from '../views/auth/LoginView.vue'
import VideoDetailView from '../views/video/VideoDetailView.vue'
import UploadView from '../views/video/UploadView.vue'
import ProfileView from '../views/profile/ProfileView.vue'
import PersonalCenterView from '../views/personal/PersonalCenterView.vue'
import MyWorksView from '../views/personal/MyWorksView.vue'
import BehaviorView from '../views/admin/BehaviorView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: HomeView },
    { path: '/login', component: LoginView },
    { path: '/videos/:id', component: VideoDetailView },
    { path: '/upload', component: UploadView, meta: { auth: true } },
    { path: '/users/:id', component: ProfileView },
    { path: '/center', component: PersonalCenterView, meta: { auth: true } },
    { path: '/works', component: MyWorksView, meta: { auth: true } },
    { path: '/behaviors', component: BehaviorView, meta: { auth: true } }
  ]
})

router.beforeEach(to => {
  if (to.meta.auth && !localStorage.getItem('token')) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
})

export default router

