<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import http, { dataOf } from '../../api/http'
import type { DataRow, PageResult } from '../../types'

const rows=ref<DataRow[]>([]);const categories=ref<DataRow[]>([]);const dialog=ref(false);const form=reactive({id:0,title:'',description:'',categoryId:0})
async function load(){rows.value=dataOf<PageResult<DataRow>>(await http.get('/me/videos',{params:{size:50}})).items}
function edit(row:DataRow){Object.assign(form,{id:row.id,title:row.title,description:row.description,categoryId:row.categoryId||row.category_id});dialog.value=true}
async function save(){await http.put(`/videos/${form.id}`,form);ElMessage.success('作品信息已更新');dialog.value=false;await load()}
async function remove(row:DataRow){await ElMessageBox.confirm(`确认删除“${row.title}”？历史行为将保留。`,'逻辑删除');await http.delete(`/videos/${row.id}`);ElMessage.success('作品已删除');await load()}
onMounted(async()=>{categories.value=dataOf(await http.get('/categories'));await load()})
</script>

<template>
  <div class="page"><div style="display:flex;justify-content:space-between"><div><h1 class="page-title">我的作品</h1><p class="page-subtitle">维护标题和简介，删除操作不会清除历史。</p></div><router-link to="/upload"><el-button type="primary" color="#d45e34">发布作品</el-button></router-link></div>
    <div class="panel"><el-table :data="rows" stripe><el-table-column prop="id" label="ID" width="70"/><el-table-column prop="title" label="标题"/><el-table-column label="状态" width="110"><template #default="s"><el-tag :type="s.row.status==='PUBLISHED'?'success':'info'">{{s.row.status}}</el-tag></template></el-table-column><el-table-column label="发布时间" width="190"><template #default="s">{{s.row.publishedAt||s.row.published_at}}</template></el-table-column><el-table-column label="操作" width="180"><template #default="s"><el-button size="small" @click="edit(s.row)" :disabled="s.row.status!=='PUBLISHED'">编辑</el-button><el-button size="small" type="danger" @click="remove(s.row)" :disabled="s.row.status!=='PUBLISHED'">删除</el-button></template></el-table-column></el-table></div>
    <el-dialog v-model="dialog" title="修改作品" width="520px"><el-form label-position="top"><el-form-item label="标题"><el-input v-model="form.title" maxlength="120"/></el-form-item><el-form-item label="简介"><el-input v-model="form.description" type="textarea" :rows="4"/></el-form-item><el-form-item label="分类"><el-select v-model="form.categoryId" style="width:100%"><el-option v-for="c in categories" :key="c.id" :label="c.name" :value="c.id"/></el-select></el-form-item></el-form><template #footer><el-button @click="dialog=false">取消</el-button><el-button type="primary" @click="save">保存</el-button></template></el-dialog>
  </div>
</template>

