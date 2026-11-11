import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import 'element-plus/dist/index.css'
import App from './App.vue'
import router from './router'
import './assets/main.css'

// 指定中文语言包，否则分页控件会显示 Total / Go to 等英文文案。
createApp(App).use(createPinia()).use(router).use(ElementPlus, { locale: zhCn }).mount('#app')
