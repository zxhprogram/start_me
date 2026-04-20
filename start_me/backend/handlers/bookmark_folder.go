package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
	"start_me_backend/middleware"
	"start_me_backend/models"
)

// CreateFolder 创建书签文件夹
func CreateFolder(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "未登录"})
		return
	}

	var req models.CreateFolderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误：" + err.Error()})
		return
	}

	// 开启事务
	tx, err := database.DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "数据库错误"})
		return
	}
	defer tx.Rollback()

	// 创建文件夹
	now := time.Now()
	res, err := tx.Exec(
		`INSERT INTO bookmark_folders (group_id, user_id, name, sort_order, created_at, updated_at) 
		VALUES (?, ?, ?, ?, ?, ?)`,
		req.GroupID, userID, req.Name, req.SortOrder, now, now,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "创建文件夹失败"})
		return
	}

	folderID, err := res.LastInsertId()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "获取文件夹ID失败"})
		return
	}

	// 将书签移动到文件夹
	for _, bookmarkID := range req.BookmarkIDs {
		_, err = tx.Exec(
			"UPDATE bookmarks SET folder_id = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?",
			folderID, bookmarkID, userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "移动书签失败"})
			return
		}
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "提交事务失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"id":   folderID,
			"name": req.Name,
		},
	})
}

// RenameFolder 重命名文件夹
func RenameFolder(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "未登录"})
		return
	}

	folderID := c.Param("id")

	var req models.RenameFolderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误：" + err.Error()})
		return
	}

	result, err := database.DB.Exec(
		"UPDATE bookmark_folders SET name = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?",
		req.Name, folderID, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "重命名失败"})
		return
	}

	rows, err := result.RowsAffected()
	if err != nil || rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "文件夹不存在"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"id":   folderID,
			"name": req.Name,
		},
	})
}

// DeleteFolder 删除文件夹（将书签移出）
func DeleteFolder(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "未登录"})
		return
	}

	folderID := c.Param("id")

	// 开启事务
	tx, err := database.DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "数据库错误"})
		return
	}
	defer tx.Rollback()

	// 获取文件夹的书签数量
	var count int
	err = tx.QueryRow(
		"SELECT COUNT(*) FROM bookmarks WHERE folder_id = ? AND user_id = ?",
		folderID, userID,
	).Scan(&count)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "查询失败"})
		return
	}

	// 将书签移出文件夹
	_, err = tx.Exec(
		"UPDATE bookmarks SET folder_id = NULL, updated_at = datetime('now') WHERE folder_id = ? AND user_id = ?",
		folderID, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "移出书签失败"})
		return
	}

	// 删除文件夹
	_, err = tx.Exec(
		"DELETE FROM bookmark_folders WHERE id = ? AND user_id = ?",
		folderID, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "删除文件夹失败"})
		return
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "提交事务失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"released_bookmarks": count,
		},
	})
}

// GetFolders 获取文件夹列表
func GetFolders(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "未登录"})
		return
	}

	groupID := c.Query("group_id")
	if groupID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "缺少分组ID"})
		return
	}

	rows, err := database.DB.Query(
		`SELECT id, group_id, user_id, name, sort_order, created_at, updated_at 
		FROM bookmark_folders 
		WHERE group_id = ? AND user_id = ?
		ORDER BY sort_order ASC, created_at ASC`,
		groupID, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "查询失败"})
		return
	}
	defer rows.Close()

	folders := []models.BookmarkFolderWithItems{}
	for rows.Next() {
		var folder models.BookmarkFolderWithItems
		err := rows.Scan(
			&folder.ID, &folder.GroupID, &folder.UserID, &folder.Name,
			&folder.SortOrder, &folder.CreatedAt, &folder.UpdatedAt,
		)
		if err != nil {
			continue
		}

		// 获取文件夹内的书签
		folder.Bookmarks = getBookmarksInFolder(folder.ID, userID)
		folders = append(folders, folder)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    folders,
	})
}

// getBookmarksInFolder 获取文件夹内的书签
func getBookmarksInFolder(folderID int64, userID int64) []models.Bookmark {
	rows, err := database.DB.Query(
		`SELECT id, group_id, user_id, folder_id, name, url, icon_type, icon_url, icon_text, color, description, sort_order 
		FROM bookmarks 
		WHERE folder_id = ? AND user_id = ?
		ORDER BY sort_order ASC`,
		folderID, userID,
	)
	if err != nil {
		return nil
	}
	defer rows.Close()

	bookmarks := []models.Bookmark{}
	for rows.Next() {
		var b models.Bookmark
		var folderID sql.NullInt64
		err := rows.Scan(
			&b.ID, &b.GroupID, &b.UserID, &folderID, &b.Name, &b.URL,
			&b.IconType, &b.IconURL, &b.IconText, &b.Color, &b.Description, &b.SortOrder,
		)
		if err != nil {
			continue
		}
		if folderID.Valid {
			b.FolderID = &folderID.Int64
		}
		bookmarks = append(bookmarks, b)
	}
	return bookmarks
}

// MoveBookmarksToFolder 移动书签到文件夹
func MoveBookmarksToFolder(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "未登录"})
		return
	}

	folderID := c.Param("id")

	var req models.MoveToFolderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误：" + err.Error()})
		return
	}

	// 验证文件夹存在且属于当前用户
	var existsFolder bool
	err := database.DB.QueryRow(
		"SELECT EXISTS(SELECT 1 FROM bookmark_folders WHERE id = ? AND user_id = ?)",
		folderID, userID,
	).Scan(&existsFolder)
	if err != nil || !existsFolder {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "文件夹不存在"})
		return
	}

	// 移动书签
	for _, bookmarkID := range req.BookmarkIDs {
		_, err = database.DB.Exec(
			"UPDATE bookmarks SET folder_id = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?",
			folderID, bookmarkID, userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "移动书签失败"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// MoveBookmarksOutOfFolder 将书签移出文件夹
func MoveBookmarksOutOfFolder(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "未登录"})
		return
	}

	var req models.MoveToFolderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误：" + err.Error()})
		return
	}

	// 移出文件夹
	for _, bookmarkID := range req.BookmarkIDs {
		_, err := database.DB.Exec(
			"UPDATE bookmarks SET folder_id = NULL, updated_at = datetime('now') WHERE id = ? AND user_id = ?",
			bookmarkID, userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "移出书签失败"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}
