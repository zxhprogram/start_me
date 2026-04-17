package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/go-resty/resty/v2"
	"start_me_backend/models"
)

const (
	githubClientID     = "Ov23li6ytqmgHWrAgh21"
	githubClientSecret = "c807785f50c6db2b502c9ec9fd090ba1da91e885"
	githubRedirectURI  = "http://localhost:8080/auth/github/callback"
)

// StartOAuth 返回 GitHub OAuth 授权 URL
func StartOAuth(c *gin.Context) {
	url := fmt.Sprintf(
		"https://github.com/login/oauth/authorize?client_id=%s&redirect_uri=%s&scope=read:user,user:email",
		githubClientID,
		githubRedirectURI,
	)
	c.JSON(http.StatusOK, models.OAuthURLResponse{
		Success: true,
		URL:     url,
	})
}

// OAuthCallback 处理 GitHub OAuth 回调
func OAuthCallback(c *gin.Context) {
	code := c.Query("code")
	if code == "" {
		c.HTML(http.StatusBadRequest, "", nil)
		c.String(http.StatusBadRequest, "缺少 code 参数")
		return
	}

	// 用 code 换取 access_token
	client := resty.New()
	resp, err := client.R().
		SetHeader("Accept", "application/json").
		SetBody(map[string]string{
			"client_id":     githubClientID,
			"client_secret": githubClientSecret,
			"code":          code,
			"redirect_uri":  githubRedirectURI,
		}).
		Post("https://github.com/login/oauth/access_token")

	if err != nil {
		c.String(http.StatusInternalServerError, "换取 token 失败: "+err.Error())
		return
	}

	var tokenResult map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &tokenResult); err != nil {
		c.String(http.StatusInternalServerError, "解析 token 失败: "+err.Error())
		return
	}

	token, ok := tokenResult["access_token"].(string)
	if !ok || token == "" {
		errMsg, _ := tokenResult["error_description"].(string)
		if errMsg == "" {
			errMsg = "获取 token 失败"
		}
		c.String(http.StatusBadRequest, errMsg)
		return
	}

	// 返回一个 HTML 页面，前端轮询获取 token
	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><title>GitHub 授权成功</title></head>
<body style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;background:#1a1a2e;color:white;">
<div style="text-align:center;">
<h2>GitHub 授权成功！</h2>
<p>请返回应用，授权信息将自动同步。</p>
<p style="color:#888;font-size:12px;">Token: %s</p>
<script>
// 通知可能的轮询
fetch('http://localhost:8080/api/github/oauth/token/store?token=%s', {method:'POST'});
</script>
</div>
</body>
</html>`, token[:8]+"...", token)
	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))

	// 存储最新 token 供前端轮询
	latestToken = token
}

// latestToken 临时存储最新的 OAuth token，供前端轮询
var latestToken string

// StoreOAuthToken 存储 token（由回调页面的 JS 调用）
func StoreOAuthToken(c *gin.Context) {
	token := c.Query("token")
	if token != "" {
		latestToken = token
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// PollOAuthToken 前端轮询获取 token
func PollOAuthToken(c *gin.Context) {
	if latestToken != "" {
		token := latestToken
		latestToken = "" // 清空，一次性使用
		c.JSON(http.StatusOK, models.OAuthTokenResponse{
			Success: true,
			Token:   token,
		})
	} else {
		c.JSON(http.StatusOK, models.OAuthTokenResponse{
			Success: false,
			Error:   "等待授权中",
		})
	}
}

// GetGitHubUser 获取 GitHub 用户信息
func GetGitHubUser(c *gin.Context) {
	token := extractToken(c)
	if token == "" {
		c.JSON(http.StatusUnauthorized, models.GitHubUserResponse{
			Success: false,
			Error:   "未提供 token",
		})
		return
	}

	client := resty.New()
	resp, err := client.R().
		SetHeader("Authorization", "Bearer "+token).
		SetHeader("Accept", "application/vnd.github.v3+json").
		SetHeader("User-Agent", "StartMe-App").
		Get("https://api.github.com/user")

	if err != nil {
		c.JSON(http.StatusOK, models.GitHubUserResponse{
			Success: false,
			Error:   "请求失败: " + err.Error(),
		})
		return
	}

	var user models.GitHubUser
	if err := json.Unmarshal(resp.Body(), &user); err != nil {
		c.JSON(http.StatusOK, models.GitHubUserResponse{
			Success: false,
			Error:   "解析失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.GitHubUserResponse{
		Success: true,
		Data:    &user,
	})
}

// GetUserStars 获取用户 star 的仓库列表（支持分页）
func GetUserStars(c *gin.Context) {
	token := extractToken(c)
	if token == "" {
		c.JSON(http.StatusUnauthorized, models.GitHubStarsResponse{
			Success: false,
			Error:   "未提供 token",
		})
		return
	}

	page := c.DefaultQuery("page", "1")
	pageNum, _ := strconv.Atoi(page)
	if pageNum < 1 {
		pageNum = 1
	}

	client := resty.New()
	resp, err := client.R().
		SetHeader("Authorization", "Bearer "+token).
		SetHeader("Accept", "application/vnd.github.v3+json").
		SetHeader("User-Agent", "StartMe-App").
		SetQueryParam("per_page", "30").
		SetQueryParam("page", strconv.Itoa(pageNum)).
		SetQueryParam("sort", "updated").
		Get("https://api.github.com/user/starred")

	if err != nil {
		c.JSON(http.StatusOK, models.GitHubStarsResponse{
			Success: false,
			Error:   "请求失败: " + err.Error(),
		})
		return
	}

	var rawRepos []map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &rawRepos); err != nil {
		c.JSON(http.StatusOK, models.GitHubStarsResponse{
			Success: false,
			Error:   "解析失败: " + err.Error(),
		})
		return
	}

	// 从 Link header 判断是否有下一页
	hasMore := false
	linkHeader := resp.Header().Get("Link")
	if strings.Contains(linkHeader, `rel="next"`) {
		hasMore = true
	}

	var repos []models.GitHubStarredRepo
	for _, raw := range rawRepos {
		fullName, _ := raw["full_name"].(string)
		desc, _ := raw["description"].(string)
		lang, _ := raw["language"].(string)
		htmlURL, _ := raw["html_url"].(string)
		stars := 0
		if s, ok := raw["stargazers_count"].(float64); ok {
			stars = int(s)
		}
		repos = append(repos, models.GitHubStarredRepo{
			Name:        fullName,
			Description: desc,
			Language:    lang,
			Stars:       stars,
			URL:         htmlURL,
		})
	}

	c.JSON(http.StatusOK, models.GitHubStarsResponse{
		Success: true,
		Data:    repos,
		Page:    pageNum,
		HasMore: hasMore,
	})
}

func extractToken(c *gin.Context) string {
	auth := c.GetHeader("Authorization")
	if strings.HasPrefix(auth, "Bearer ") {
		return strings.TrimPrefix(auth, "Bearer ")
	}
	return c.Query("token")
}
