package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-resty/resty/v2"
)

var searchClient = resty.New().SetTimeout(3 * time.Second)

func GetSearchSuggestions(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []string{}})
		return
	}

	engine := c.DefaultQuery("engine", "百度")

	var url string
	switch engine {
	case "必应":
		url = "https://api.bing.com/osjson.aspx?query=" + query
	case "Google":
		url = "https://suggestqueries.google.com/complete/search?client=firefox&q=" + query
	default:
		// 百度、GitHub、DuckDuckGo、开发者搜索 均 fallback 到百度
		url = "https://suggestion.baidu.com/su?wd=" + query + "&action=opensearch"
	}

	resp, err := searchClient.R().
		SetHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36").
		Get(url)

	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []string{}})
		return
	}

	// OpenSearch JSON 格式: ["query", ["sug1", "sug2", ...]]
	var result []json.RawMessage
	if err := json.Unmarshal(resp.Body(), &result); err != nil || len(result) < 2 {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []string{}})
		return
	}

	var suggestions []string
	if err := json.Unmarshal(result[1], &suggestions); err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []string{}})
		return
	}

	// 限制最多 10 条
	if len(suggestions) > 10 {
		suggestions = suggestions[:10]
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": suggestions})
}
