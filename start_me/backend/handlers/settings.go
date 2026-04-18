package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
)

type settingResponse struct {
	Success bool              `json:"success"`
	Data    map[string]string `json:"data,omitempty"`
	Error   string            `json:"error,omitempty"`
}

type setSettingRequest struct {
	Value string `json:"value" binding:"required"`
}

// GetSetting 获取设置
func GetSetting(c *gin.Context) {
	key := c.Param("key")

	var value string
	err := database.DB.QueryRow("SELECT value FROM settings WHERE key = ?", key).Scan(&value)
	if err != nil {
		c.JSON(http.StatusOK, settingResponse{
			Success: true,
			Data:    nil,
		})
		return
	}

	c.JSON(http.StatusOK, settingResponse{
		Success: true,
		Data:    map[string]string{"key": key, "value": value},
	})
}

// SetSetting 设置/更新设置
func SetSetting(c *gin.Context) {
	key := c.Param("key")

	var req setSettingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, settingResponse{
			Success: false,
			Error:   "参数错误：" + err.Error(),
		})
		return
	}

	_, err := database.DB.Exec(
		"INSERT OR REPLACE INTO settings (key, value, updated_at) VALUES (?, ?, datetime('now'))",
		key, req.Value,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, settingResponse{
			Success: false,
			Error:   "保存失败：" + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, settingResponse{
		Success: true,
		Data:    map[string]string{"key": key, "value": req.Value},
	})
}
