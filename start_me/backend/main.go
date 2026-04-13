package main

import (
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"start_me_backend/handlers"
)

func main() {
	r := gin.Default()

	// CORS 配置
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowMethods = []string{"GET", "POST", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept"}
	config.MaxAge = 12 * time.Hour
	r.Use(cors.New(config))

	// API 路由
	api := r.Group("/api")
	{
		api.POST("/fetch", handlers.FetchWebInfo)
		api.GET("/proxy/icon", handlers.ProxyIcon)
		api.GET("/github/trending", handlers.GetTrendingRepos)
	}

	// 启动服务
	r.Run(":8080")
}
