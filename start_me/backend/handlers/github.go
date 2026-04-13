package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"start_me_backend/models"
	"start_me_backend/services"
)

// GetTrendingRepos 获取 GitHub Trending 仓库
func GetTrendingRepos(c *gin.Context) {
	period := c.DefaultQuery("period", "daily")

	// Validate period
	if period != "daily" && period != "weekly" && period != "monthly" {
		c.JSON(http.StatusBadRequest, models.TrendingResponse{
			Success: false,
			Error:   "无效的 period 参数，可选值: daily, weekly, monthly",
		})
		return
	}

	repos, err := services.GetTrendingRepos(period)
	if err != nil {
		c.JSON(http.StatusOK, models.TrendingResponse{
			Success: false,
			Error:   "获取 GitHub Trending 失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.TrendingResponse{
		Success: true,
		Data:    repos,
	})
}
