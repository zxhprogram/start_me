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

// GetGitHubFeed 获取用户的 GitHub Feed（received events）
func GetGitHubFeed(c *gin.Context) {
	token := extractToken(c)
	if token == "" {
		c.JSON(http.StatusUnauthorized, models.GitHubFeedResponse{
			Success: false,
			Error:   "未提供 token",
		})
		return
	}

	login := c.Query("login")
	if login == "" {
		// 先获取用户 login
		client := resty.New()
		resp, err := client.R().
			SetHeader("Authorization", "Bearer "+token).
			SetHeader("Accept", "application/vnd.github.v3+json").
			SetHeader("User-Agent", "StartMe-App").
			Get("https://api.github.com/user")
		if err != nil {
			c.JSON(http.StatusOK, models.GitHubFeedResponse{Success: false, Error: "获取用户信息失败"})
			return
		}
		var user map[string]interface{}
		if err := json.Unmarshal(resp.Body(), &user); err != nil {
			c.JSON(http.StatusOK, models.GitHubFeedResponse{Success: false, Error: "解析用户信息失败"})
			return
		}
		login, _ = user["login"].(string)
		if login == "" {
			c.JSON(http.StatusOK, models.GitHubFeedResponse{Success: false, Error: "无法获取用户名"})
			return
		}
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
		Get(fmt.Sprintf("https://api.github.com/users/%s/received_events", login))

	if err != nil {
		c.JSON(http.StatusOK, models.GitHubFeedResponse{Success: false, Error: "请求失败: " + err.Error()})
		return
	}

	var rawEvents []map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &rawEvents); err != nil {
		c.JSON(http.StatusOK, models.GitHubFeedResponse{Success: false, Error: "解析失败: " + err.Error()})
		return
	}

	hasMore := false
	linkHeader := resp.Header().Get("Link")
	if strings.Contains(linkHeader, `rel="next"`) {
		hasMore = true
	}

	var events []models.GitHubFeedEvent
	for _, raw := range rawEvents {
		eventType, _ := raw["type"].(string)

		// actor
		actorMap, _ := raw["actor"].(map[string]interface{})
		actorLogin, _ := actorMap["login"].(string)
		actorAvatar, _ := actorMap["avatar_url"].(string)

		// repo
		repoMap, _ := raw["repo"].(map[string]interface{})
		repoName, _ := repoMap["name"].(string)

		// payload
		payload, _ := raw["payload"].(map[string]interface{})

		// created_at
		createdAt, _ := raw["created_at"].(string)

		desc, detail := buildEventDesc(eventType, payload, repoName)

		events = append(events, models.GitHubFeedEvent{
			Actor:       actorLogin,
			ActorAvatar: actorAvatar,
			EventType:   eventType,
			EventDesc:   desc,
			RepoName:    repoName,
			Detail:      detail,
			CreatedAt:   createdAt,
		})
	}

	c.JSON(http.StatusOK, models.GitHubFeedResponse{
		Success: true,
		Data:    events,
		Page:    pageNum,
		HasMore: hasMore,
	})
}

// buildEventDesc 根据事件类型生成中文描述和详情
func buildEventDesc(eventType string, payload map[string]interface{}, repoName string) (string, string) {
	switch eventType {
	case "WatchEvent":
		return "starred", ""
	case "CreateEvent":
		refType, _ := payload["ref_type"].(string)
		ref, _ := payload["ref"].(string)
		refTypeZh := refType
		switch refType {
		case "repository":
			refTypeZh = "仓库"
		case "branch":
			refTypeZh = "分支"
		case "tag":
			refTypeZh = "标签"
		}
		if ref != "" {
			return "创建了" + refTypeZh, ref
		}
		return "创建了" + refTypeZh, ""
	case "ForkEvent":
		forkee, _ := payload["forkee"].(map[string]interface{})
		fullName, _ := forkee["full_name"].(string)
		return "fork 了", fullName
	case "PushEvent":
		size := 0
		if s, ok := payload["size"].(float64); ok {
			size = int(s)
		}
		commits, _ := payload["commits"].([]interface{})
		detail := ""
		if len(commits) > 0 {
			lastCommit, _ := commits[len(commits)-1].(map[string]interface{})
			msg, _ := lastCommit["message"].(string)
			if len(msg) > 80 {
				msg = msg[:80] + "..."
			}
			detail = msg
		}
		return fmt.Sprintf("推送了 %d 个提交到", size), detail
	case "PullRequestEvent":
		action, _ := payload["action"].(string)
		pr, _ := payload["pull_request"].(map[string]interface{})
		number := 0
		title := ""
		if n, ok := payload["number"].(float64); ok {
			number = int(n)
		}
		if pr != nil {
			title, _ = pr["title"].(string)
			if merged, ok := pr["merged"].(bool); ok && merged && action == "closed" {
				action = "merged"
			}
		}
		actionZh := action
		switch action {
		case "opened":
			actionZh = "创建了"
		case "closed":
			actionZh = "关闭了"
		case "merged":
			actionZh = "合并了"
		case "reopened":
			actionZh = "重新打开了"
		}
		return fmt.Sprintf("%s PR #%d", actionZh, number), title
	case "IssuesEvent":
		action, _ := payload["action"].(string)
		number := 0
		if n, ok := payload["number"].(float64); ok {
			number = int(n)
		}
		issue, _ := payload["issue"].(map[string]interface{})
		title := ""
		if issue != nil {
			title, _ = issue["title"].(string)
		}
		actionZh := action
		switch action {
		case "opened":
			actionZh = "创建了"
		case "closed":
			actionZh = "关闭了"
		case "reopened":
			actionZh = "重新打开了"
		}
		return fmt.Sprintf("%s issue #%d", actionZh, number), title
	case "IssueCommentEvent":
		issue, _ := payload["issue"].(map[string]interface{})
		number := 0
		if issue != nil {
			if n, ok := issue["number"].(float64); ok {
				number = int(n)
			}
		}
		comment, _ := payload["comment"].(map[string]interface{})
		body := ""
		if comment != nil {
			body, _ = comment["body"].(string)
			if len(body) > 80 {
				body = body[:80] + "..."
			}
		}
		return fmt.Sprintf("评论了 #%d", number), body
	case "ReleaseEvent":
		release, _ := payload["release"].(map[string]interface{})
		tag := ""
		if release != nil {
			tag, _ = release["tag_name"].(string)
		}
		return "发布了", tag
	case "DeleteEvent":
		refType, _ := payload["ref_type"].(string)
		ref, _ := payload["ref"].(string)
		return "删除了 " + refType, ref
	case "PublicEvent":
		return "公开了", ""
	case "MemberEvent":
		action, _ := payload["action"].(string)
		member, _ := payload["member"].(map[string]interface{})
		memberLogin := ""
		if member != nil {
			memberLogin, _ = member["login"].(string)
		}
		if action == "added" {
			return "添加了成员", memberLogin
		}
		return action + " 成员", memberLogin
	case "GollumEvent":
		return "更新了 Wiki", ""
	case "CommitCommentEvent":
		return "评论了提交", ""
	default:
		return eventType, ""
	}
}
