package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
	"start_me_backend/middleware"
)

type userSettingResponse struct {
	Success bool              `json:"success"`
	Data    map[string]string `json:"data,omitempty"`
	Error   string            `json:"error,omitempty"`
}

type setUserSettingRequest struct {
	Value string `json:"value" binding:"required"`
}

// GetUserSetting 获取当前用户的设置
func GetUserSetting(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, userSettingResponse{
			Success: false,
			Error:   "未登录",
		})
		return
	}

	key := c.Param("key")

	var value string
	err := database.DB.QueryRow(
		"SELECT value FROM user_settings WHERE user_id = ? AND key = ?",
		userID, key,
	).Scan(&value)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusOK, userSettingResponse{
			Success: true,
			Data:    nil,
		})
		return
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, userSettingResponse{
			Success: false,
			Error:   "查询失败：" + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, userSettingResponse{
		Success: true,
		Data: map[string]string{
			"key":   key,
			"value": value,
		},
	})
}

// SetUserSetting 设置/更新当前用户的设置
func SetUserSetting(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, userSettingResponse{
			Success: false,
			Error:   "未登录",
		})
		return
	}

	key := c.Param("key")

	var req setUserSettingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, userSettingResponse{
			Success: false,
			Error:   "参数错误：" + err.Error(),
		})
		return
	}

	_, err := database.DB.Exec(
		`INSERT INTO user_settings (user_id, key, value, updated_at) 
		VALUES (?, ?, ?, datetime('now'))
		ON CONFLICT(user_id, key) 
		DO UPDATE SET value = excluded.value, updated_at = datetime('now')`,
		userID, key, req.Value,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, userSettingResponse{
			Success: false,
			Error:   "保存失败：" + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, userSettingResponse{
		Success: true,
		Data: map[string]string{
			"key":   key,
			"value": req.Value,
		},
	})
}

// DeleteUserSetting 删除当前用户的设置
func DeleteUserSetting(c *gin.Context) {
	userID, exists := middleware.GetUserID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, userSettingResponse{
			Success: false,
			Error:   "未登录",
		})
		return
	}

	key := c.Param("key")

	_, err := database.DB.Exec(
		"DELETE FROM user_settings WHERE user_id = ? AND key = ?",
		userID, key,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, userSettingResponse{
			Success: false,
			Error:   "删除失败：" + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, userSettingResponse{
		Success: true,
	})
}
