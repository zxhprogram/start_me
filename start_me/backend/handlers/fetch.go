package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"start_me_backend/models"
	"start_me_backend/services"
)

// FetchWebInfo 抓取网页信息
func FetchWebInfo(c *gin.Context) {
	var req models.FetchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.FetchResponse{
			Success: false,
			Error:   "无效的 URL",
		})
		return
	}

	data, err := services.FetchWebInfo(req.URL)
	if err != nil {
		c.JSON(http.StatusOK, models.FetchResponse{
			Success: false,
			Error:   "无法获取网页信息",
		})
		return
	}

	c.JSON(http.StatusOK, models.FetchResponse{
		Success: true,
		Data:    data,
	})
}

// ProxyIcon 代理图标请求
func ProxyIcon(c *gin.Context) {
	iconURL := c.Query("url")
	if iconURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "缺少 url 参数"})
		return
	}

	data, contentType, err := services.FetchIcon(iconURL)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "无法获取图标"})
		return
	}

	// 设置缓存头
	c.Header("Cache-Control", "public, max-age=86400")
	c.Header("Expires", time.Now().Add(24*time.Hour).Format(http.TimeFormat))

	if contentType != "" {
		c.Data(http.StatusOK, contentType, data)
	} else {
		c.Data(http.StatusOK, "image/x-icon", data)
	}
}
