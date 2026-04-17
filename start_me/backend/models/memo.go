package models

import "time"

// Memo 备忘录
type Memo struct {
	ID        int64     `json:"id"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// MemoResponse 备忘录响应
type MemoResponse struct {
	Success bool   `json:"success"`
	Data    []Memo `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

// MemoItemResponse 单个备忘录响应
type MemoItemResponse struct {
	Success bool   `json:"success"`
	Data    *Memo  `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

// CreateMemoRequest 创建备忘录请求
type CreateMemoRequest struct {
	Content string `json:"content" binding:"required"`
}

// UpdateMemoRequest 更新备忘录请求
type UpdateMemoRequest struct {
	Content string `json:"content" binding:"required"`
}

// DeleteMemoResponse 删除响应
type DeleteMemoResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}
