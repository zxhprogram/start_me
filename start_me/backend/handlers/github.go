package handlers

import (
	"encoding/base64"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-resty/resty/v2"
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

// GetRepoReadme 获取 GitHub 仓库 README
func GetRepoReadme(c *gin.Context) {
	repo := c.Query("repo")
	if repo == "" {
		c.JSON(http.StatusBadRequest, models.ReadmeResponse{
			Success: false,
			Error:   "缺少 repo 参数",
		})
		return
	}

	client := resty.New()
	resp, err := client.R().
		SetHeader("Accept", "application/vnd.github.v3+json").
		SetHeader("User-Agent", "StartMe-App").
		Get("https://api.github.com/repos/" + repo + "/readme")

	if err != nil {
		c.JSON(http.StatusOK, models.ReadmeResponse{
			Success: false,
			Error:   "请求 GitHub API 失败: " + err.Error(),
		})
		return
	}

	if resp.StatusCode() != 200 {
		c.JSON(http.StatusOK, models.ReadmeResponse{
			Success: false,
			Error:   "获取 README 失败，状态码: " + resp.Status(),
		})
		return
	}

	// 解析 GitHub API 返回的 JSON
	var result map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &result); err != nil {
		c.JSON(http.StatusOK, models.ReadmeResponse{
			Success: false,
			Error:   "解析响应失败: " + err.Error(),
		})
		return
	}

	// 获取 base64 编码的内容
	content, ok := result["content"].(string)
	if !ok {
		c.JSON(http.StatusOK, models.ReadmeResponse{
			Success: false,
			Error:   "README 内容为空",
		})
		return
	}

	// 解码 base64
	decoded, err := base64.StdEncoding.DecodeString(content)
	if err != nil {
		c.JSON(http.StatusOK, models.ReadmeResponse{
			Success: false,
			Error:   "解码 README 失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.ReadmeResponse{
		Success: true,
		Data:    string(decoded),
	})
}
