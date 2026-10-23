export interface ApiResponse<T> {
  success: boolean
  message: string
  data: T
}

export interface PageResult<T> {
  items: T[]
  total: number
  page: number
  size: number
}

export type DataRow = Record<string, any>

