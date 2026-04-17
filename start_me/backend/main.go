package main

import (
	"log"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"start_me_backend/database"
	"start_me_backend/handlers"
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
		// 天气路由
		api.GET("/weather", handlers.GetWeather)
		api.GET("/weather/search", handlers.SearchCity)
	}

	// GitHub OAuth 回调（路径与 GitHub App 配置一致）
	r.GET("/auth/github/callback", handlers.OAuthCallback)

	// 启动服务
	r.Run(":8080")
}
