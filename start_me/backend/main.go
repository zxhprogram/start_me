package main

import (
	"log"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"start_me_backend/database"
	"start_me_backend/handlers"
	"start_me_backend/middleware"
)

func main() {
	// 初始化数据库
	err := database.InitDB("memos.db")
	if err != nil {
		log.Fatal("数据库初始化失败:", err)
	}
	defer database.CloseDB()

	// 创建数据表
	err = database.CreateTables()
	if err != nil {
		log.Fatal("创建数据表失败:", err)
	}

	r := gin.Default()

	// CORS 配置
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization"}
	config.MaxAge = 12 * time.Hour
	r.Use(cors.New(config))

	// API 路由
	api := r.Group("/api")
	{
		api.POST("/fetch", handlers.FetchWebInfo)
		api.GET("/proxy/icon", handlers.ProxyIcon)
		api.GET("/github/trending", handlers.GetTrendingRepos)
		api.GET("/github/readme", handlers.GetRepoReadme)
		// 备忘录路由
		api.GET("/memos", handlers.GetMemos)
		api.POST("/memos", handlers.CreateMemo)
		api.DELETE("/memos/:id", handlers.DeleteMemo)
		api.PUT("/memos/:id", handlers.UpdateMemo)
		// GitHub OAuth 路由
		api.GET("/github/oauth/url", handlers.StartOAuth)
		api.POST("/github/oauth/token/store", handlers.StoreOAuthToken)
		api.GET("/github/oauth/token/poll", handlers.PollOAuthToken)
		api.GET("/github/user", handlers.GetGitHubUser)
		api.GET("/github/stars", handlers.GetUserStars)
		api.GET("/github/feed", handlers.GetGitHubFeed)
		// 天气路由
		api.GET("/weather", handlers.GetWeather)
		api.GET("/weather/search", handlers.SearchCity)
		// 搜索建议
		api.GET("/search/suggestions", handlers.GetSearchSuggestions)
		// 热搜榜
		api.GET("/tophub/hot", handlers.GetHotTopics)
		api.GET("/tophub/nodes", handlers.GetTopHubNodes)
		// 设置
		api.GET("/settings/:key", handlers.GetSetting)
		api.PUT("/settings/:key", handlers.SetSetting)
		// 按键统计
		api.GET("/keystrokes/top", handlers.GetTopKeystrokes)
		api.GET("/keystrokes/all", handlers.GetAllKeystrokes)
		api.PUT("/keystrokes/sync", handlers.SyncKeystrokes)
		// 用户认证（公开）
		api.POST("/auth/register", handlers.Register)
		api.POST("/auth/login", handlers.Login)
		api.POST("/auth/github", handlers.GitHubLogin)
	}

	// 需要登录的路由
	authApi := api.Group("/", middleware.AuthMiddleware())
	{
		authApi.GET("/auth/profile", handlers.GetProfile)
		authApi.GET("/bookmarks/groups", handlers.GetBookmarkGroups)
		authApi.PUT("/bookmarks/groups", handlers.SaveBookmarkGroups)
		authApi.DELETE("/bookmarks/groups/:id", handlers.DeleteBookmarkGroup)
		// 书签文件夹
		authApi.GET("/bookmarks/folders", handlers.GetFolders)
		authApi.POST("/bookmarks/folders", handlers.CreateFolder)
		authApi.PUT("/bookmarks/folders/:id", handlers.RenameFolder)
		authApi.DELETE("/bookmarks/folders/:id", handlers.DeleteFolder)
		authApi.PUT("/bookmarks/folders/:id/bookmarks", handlers.MoveBookmarksToFolder)
		authApi.DELETE("/bookmarks/folders/:id/bookmarks", handlers.MoveBookmarksOutOfFolder)
		// 邮箱配置
		authApi.GET("/email/config", handlers.GetEmailConfig)
		authApi.PUT("/email/config", handlers.SaveEmailConfig)
		authApi.DELETE("/email/config", handlers.DeleteEmailConfig)
		authApi.GET("/email/list", handlers.GetEmails)
		authApi.GET("/email/detail/:id", handlers.GetEmailDetail)
		// 用户设置
		authApi.GET("/user/settings/:key", handlers.GetUserSetting)
		authApi.PUT("/user/settings/:key", handlers.SetUserSetting)
		authApi.DELETE("/user/settings/:key", handlers.DeleteUserSetting)
	}

	// GitHub OAuth 回调（路径与 GitHub App 配置一致）
	r.GET("/auth/github/callback", handlers.OAuthCallback)

	// 启动服务
	r.Run(":8080")
}
