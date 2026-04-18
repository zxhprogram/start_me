package models

// GitHubUser GitHub 用户信息
type GitHubUser struct {
	Login     string `json:"login"`
	AvatarURL string `json:"avatar_url"`
	Name      string `json:"name"`
}

// GitHubUserResponse GitHub 用户响应
type GitHubUserResponse struct {
	Success bool        `json:"success"`
	Data    *GitHubUser `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// GitHubStarredRepo GitHub Star 的仓库
type GitHubStarredRepo struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Language    string `json:"language"`
	Stars       int    `json:"stars"`
	URL         string `json:"url"`
}

// GitHubStarsResponse GitHub Stars 响应
type GitHubStarsResponse struct {
	Success bool                `json:"success"`
	Data    []GitHubStarredRepo `json:"data,omitempty"`
	Page    int                 `json:"page,omitempty"`
	HasMore bool                `json:"has_more"`
	Error   string              `json:"error,omitempty"`
}

// OAuthURLResponse OAuth URL 响应
type OAuthURLResponse struct {
	Success bool   `json:"success"`
	URL     string `json:"url,omitempty"`
	Error   string `json:"error,omitempty"`
}

// OAuthTokenResponse OAuth Token 响应
type OAuthTokenResponse struct {
	Success bool   `json:"success"`
	Token   string `json:"token,omitempty"`
	Error   string `json:"error,omitempty"`
}

// GitHubFeedEvent GitHub Feed 事件
type GitHubFeedEvent struct {
	Actor       string `json:"actor"`
	ActorAvatar string `json:"actor_avatar"`
	EventType   string `json:"event_type"`
	EventDesc   string `json:"event_desc"`
	RepoName    string `json:"repo_name"`
	Detail      string `json:"detail"`
	CreatedAt   string `json:"created_at"`
}

// GitHubFeedResponse GitHub Feed 响应
type GitHubFeedResponse struct {
	Success bool              `json:"success"`
	Data    []GitHubFeedEvent `json:"data,omitempty"`
	Page    int               `json:"page,omitempty"`
	HasMore bool              `json:"has_more"`
	Error   string            `json:"error,omitempty"`
}
