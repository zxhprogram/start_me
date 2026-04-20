package models

import "time"

// BookmarkFolder 书签文件夹
type BookmarkFolder struct {
	ID        int64     `json:"id"`
	GroupID   int64     `json:"group_id"`
	UserID    int64     `json:"user_id"`
	Name      string    `json:"name"`
	SortOrder int       `json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// BookmarkFolderWithItems 包含书签的文件夹
type BookmarkFolderWithItems struct {
	BookmarkFolder
	Bookmarks []Bookmark `json:"bookmarks"`
}

// Bookmark 书签
type Bookmark struct {
	ID          int64  `json:"id"`
	GroupID     int64  `json:"group_id"`
	UserID      int64  `json:"user_id"`
	FolderID    *int64 `json:"folder_id,omitempty"`
	Name        string `json:"name"`
	URL         string `json:"url"`
	IconType    string `json:"icon_type"`
	IconURL     string `json:"icon_url"`
	IconText    string `json:"icon_text"`
	Color       int64  `json:"color"`
	Description string `json:"description"`
	SortOrder   int    `json:"sort_order"`
}

// CreateFolderRequest 创建文件夹请求
type CreateFolderRequest struct {
	GroupID     int64   `json:"group_id" binding:"required"`
	Name        string  `json:"name" binding:"required"`
	SortOrder   int     `json:"sort_order"`
	BookmarkIDs []int64 `json:"bookmark_ids" binding:"required,min=2"`
}

// RenameFolderRequest 重命名文件夹请求
type RenameFolderRequest struct {
	Name string `json:"name" binding:"required"`
}

// MoveToFolderRequest 移动书签到文件夹请求
type MoveToFolderRequest struct {
	BookmarkIDs []int64 `json:"bookmark_ids" binding:"required"`
}
