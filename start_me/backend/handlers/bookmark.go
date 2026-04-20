package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
)

type bookmarkGroup struct {
	ID        int64                `json:"id"`
	Label     string               `json:"label"`
	Icon      string               `json:"icon"`
	SortOrder int                  `json:"sort_order"`
	Bookmarks []bookmark           `json:"bookmarks"`
	Folders   []bookmarkFolderData `json:"folders"`
}

type bookmarkFolderData struct {
	ID        int64      `json:"id"`
	Name      string     `json:"name"`
	SortOrder int        `json:"sort_order"`
	Bookmarks []bookmark `json:"bookmarks"`
}

type bookmark struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	URL         string `json:"url"`
	IconType    string `json:"icon_type"`
	IconURL     string `json:"icon_url"`
	IconText    string `json:"icon_text"`
	Color       int64  `json:"color"`
	Description string `json:"description"`
	SortOrder   int    `json:"sort_order"`
	FolderID    *int64 `json:"folder_id,omitempty"`
}

type saveGroupsRequest struct {
	Groups []saveGroup `json:"groups" binding:"required"`
}

type saveGroup struct {
	Label     string         `json:"label"`
	Icon      string         `json:"icon"`
	SortOrder int            `json:"sort_order"`
	Bookmarks []saveBookmark `json:"bookmarks"`
	Folders   []saveFolder   `json:"folders"`
}

type saveFolder struct {
	Name      string         `json:"name"`
	SortOrder int            `json:"sort_order"`
	Bookmarks []saveBookmark `json:"bookmarks"`
}

type saveBookmark struct {
	Name        string `json:"name"`
	URL         string `json:"url"`
	IconType    string `json:"icon_type"`
	IconURL     string `json:"icon_url"`
	IconText    string `json:"icon_text"`
	Color       int64  `json:"color"`
	Description string `json:"description"`
	SortOrder   int    `json:"sort_order"`
	FolderID    *int64 `json:"folder_id,omitempty"`
}

// GetBookmarkGroups 获取用户所有分组及书签（包含文件夹）
func GetBookmarkGroups(c *gin.Context) {
	userID := c.GetInt64("user_id")

	// 查询分组
	rows, err := database.DB.Query(
		"SELECT id, label, icon, sort_order FROM bookmark_groups WHERE user_id = ? ORDER BY sort_order",
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "查询失败"})
		return
	}
	defer rows.Close()

	var groups []bookmarkGroup
	for rows.Next() {
		var g bookmarkGroup
		rows.Scan(&g.ID, &g.Label, &g.Icon, &g.SortOrder)
		g.Bookmarks = []bookmark{}
		g.Folders = []bookmarkFolderData{}
		groups = append(groups, g)
	}

	// 查询每个分组的书签和文件夹
	for i := range groups {
		groupID := groups[i].ID

		// 查询文件夹
		folderRows, err := database.DB.Query(
			"SELECT id, name, sort_order FROM bookmark_folders WHERE group_id = ? AND user_id = ? ORDER BY sort_order, created_at",
			groupID, userID,
		)
		if err != nil {
			continue
		}

		folderMap := make(map[int64]*bookmarkFolderData)
		for folderRows.Next() {
			var f bookmarkFolderData
			folderRows.Scan(&f.ID, &f.Name, &f.SortOrder)
			f.Bookmarks = []bookmark{}
			groups[i].Folders = append(groups[i].Folders, f)
			folderMap[f.ID] = &groups[i].Folders[len(groups[i].Folders)-1]
		}
		folderRows.Close()

		// 查询书签（包括文件夹内和文件夹外的）
		bRows, err := database.DB.Query(
			`SELECT id, name, url, icon_type, COALESCE(icon_url,''), COALESCE(icon_text,''), color, COALESCE(description,''), sort_order, folder_id 
			FROM bookmarks 
			WHERE group_id = ? AND user_id = ? 
			ORDER BY sort_order`,
			groupID, userID,
		)
		if err != nil {
			continue
		}

		for bRows.Next() {
			var b bookmark
			var folderID sql.NullInt64
			bRows.Scan(&b.ID, &b.Name, &b.URL, &b.IconType, &b.IconURL, &b.IconText, &b.Color, &b.Description, &b.SortOrder, &folderID)

			if folderID.Valid {
				b.FolderID = &folderID.Int64
				// 放入对应文件夹
				if f, ok := folderMap[folderID.Int64]; ok {
					f.Bookmarks = append(f.Bookmarks, b)
				}
			} else {
				// 直接放在分组下
				groups[i].Bookmarks = append(groups[i].Bookmarks, b)
			}
		}
		bRows.Close()
	}

	if groups == nil {
		groups = []bookmarkGroup{}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": groups})
}

// SaveBookmarkGroups 全量保存用户分组+书签（包含文件夹）
func SaveBookmarkGroups(c *gin.Context) {
	userID := c.GetInt64("user_id")

	var req saveGroupsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误：" + err.Error()})
		return
	}

	tx, err := database.DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "事务开始失败"})
		return
	}

	// 删除旧数据（级联删除书签和文件夹）
	tx.Exec("DELETE FROM bookmarks WHERE user_id = ?", userID)
	tx.Exec("DELETE FROM bookmark_folders WHERE user_id = ?", userID)
	tx.Exec("DELETE FROM bookmark_groups WHERE user_id = ?", userID)

	// 插入新数据
	for _, g := range req.Groups {
		result, err := tx.Exec(
			"INSERT INTO bookmark_groups (user_id, label, icon, sort_order) VALUES (?, ?, ?, ?)",
			userID, g.Label, g.Icon, g.SortOrder,
		)
		if err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "保存分组失败"})
			return
		}
		groupID, _ := result.LastInsertId()

		// 先保存文件夹，建立ID映射
		folderIDMap := make(map[int]int64) // 旧sort_order -> 新ID
		for _, f := range g.Folders {
			folderResult, err := tx.Exec(
				"INSERT INTO bookmark_folders (group_id, user_id, name, sort_order) VALUES (?, ?, ?, ?)",
				groupID, userID, f.Name, f.SortOrder,
			)
			if err != nil {
				tx.Rollback()
				c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "保存文件夹失败"})
				return
			}
			newFolderID, _ := folderResult.LastInsertId()
			folderIDMap[f.SortOrder] = newFolderID
		}

		// 保存书签
		for _, b := range g.Bookmarks {
			var folderID interface{} = nil
			if b.FolderID != nil {
				// 如果bookmark有folder_id，使用它
				folderID = *b.FolderID
			}

			_, err := tx.Exec(
				"INSERT INTO bookmarks (group_id, user_id, folder_id, name, url, icon_type, icon_url, icon_text, color, description, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
				groupID, userID, folderID, b.Name, b.URL, b.IconType, b.IconURL, b.IconText, b.Color, b.Description, b.SortOrder,
			)
			if err != nil {
				tx.Rollback()
				c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "保存书签失败"})
				return
			}
		}
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "提交事务失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// DeleteBookmarkGroup 删除指定分组
func DeleteBookmarkGroup(c *gin.Context) {
	userID := c.GetInt64("user_id")
	groupID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "无效的 ID"})
		return
	}

	// 检查是否是主页（sort_order == 0 的第一个分组）
	var sortOrder int
	err = database.DB.QueryRow(
		"SELECT sort_order FROM bookmark_groups WHERE id = ? AND user_id = ?",
		groupID, userID,
	).Scan(&sortOrder)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "分组不存在"})
		return
	}
	if sortOrder == 0 {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": "主页不可删除"})
		return
	}

	database.DB.Exec("DELETE FROM bookmarks WHERE group_id = ? AND user_id = ?", groupID, userID)
	database.DB.Exec("DELETE FROM bookmark_groups WHERE id = ? AND user_id = ?", groupID, userID)

	c.JSON(http.StatusOK, gin.H{"success": true})
}
