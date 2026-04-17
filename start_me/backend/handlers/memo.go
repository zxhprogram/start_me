package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
	"start_me_backend/models"
)

// GetMemos 获取所有备忘录
func GetMemos(c *gin.Context) {
	rows, err := database.DB.Query(`
		SELECT id, content, created_at, updated_at
		FROM memos
		ORDER BY created_at DESC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.MemoResponse{
			Success: false,
			Error:   "获取备忘录失败：" + err.Error(),
		})
		return
	}
	defer rows.Close()

	memos := []models.Memo{}
	for rows.Next() {
		var memo models.Memo
		err := rows.Scan(&memo.ID, &memo.Content, &memo.CreatedAt, &memo.UpdatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.MemoResponse{
				Success: false,
				Error:   "解析数据失败：" + err.Error(),
			})
			return
		}
		memos = append(memos, memo)
	}

	c.JSON(http.StatusOK, models.MemoResponse{
		Success: true,
		Data:    memos,
	})
}

// CreateMemo 创建备忘录
func CreateMemo(c *gin.Context) {
	var req models.CreateMemoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.MemoItemResponse{
			Success: false,
			Error:   "参数错误：" + err.Error(),
		})
		return
	}

	result, err := database.DB.Exec(
		"INSERT INTO memos (content, created_at, updated_at) VALUES (?, datetime('now'), datetime('now'))",
		req.Content,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.MemoItemResponse{
			Success: false,
			Error:   "创建失败：" + err.Error(),
		})
		return
	}

	id, err := result.LastInsertId()
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.MemoItemResponse{
			Success: false,
			Error:   "获取 ID 失败：" + err.Error(),
		})
		return
	}

	// 查询刚创建的备忘录
	var memo models.Memo
	err = database.DB.QueryRow(`
		SELECT id, content, created_at, updated_at
		FROM memos
		WHERE id = ?
	`, id).Scan(&memo.ID, &memo.Content, &memo.CreatedAt, &memo.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, models.MemoItemResponse{
			Success: false,
			Error:   "查询失败：" + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.MemoItemResponse{
		Success: true,
		Data:    &memo,
	})
}

// DeleteMemo 删除备忘录
func DeleteMemo(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.DeleteMemoResponse{
			Success: false,
			Message: "",
			Error:   "无效的 ID",
		})
		return
	}

	result, err := database.DB.Exec("DELETE FROM memos WHERE id = ?", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.DeleteMemoResponse{
			Success: false,
			Error:   "删除失败：" + err.Error(),
		})
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, models.DeleteMemoResponse{
			Success: false,
			Message: "",
			Error:   "备忘录不存在",
		})
		return
	}

	c.JSON(http.StatusOK, models.DeleteMemoResponse{
		Success: true,
		Message: "删除成功",
	})
}

// UpdateMemo 更新备忘录
func UpdateMemo(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.MemoItemResponse{
			Success: false,
			Error:   "无效的 ID",
		})
		return
	}

	var req models.UpdateMemoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.MemoItemResponse{
			Success: false,
			Error:   "参数错误：" + err.Error(),
		})
		return
	}

	_, err = database.DB.Exec(
		"UPDATE memos SET content = ?, updated_at = datetime('now') WHERE id = ?",
		req.Content,
		id,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.MemoItemResponse{
			Success: false,
			Error:   "更新失败：" + err.Error(),
		})
		return
	}

	// 查询更新后的备忘录
	var memo models.Memo
	err = database.DB.QueryRow(`
		SELECT id, content, created_at, updated_at
		FROM memos
		WHERE id = ?
	`, id).Scan(&memo.ID, &memo.Content, &memo.CreatedAt, &memo.UpdatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, models.MemoItemResponse{
			Success: false,
			Error:   "查询失败：" + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.MemoItemResponse{
		Success: true,
		Data:    &memo,
	})
}
