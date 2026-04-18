package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-resty/resty/v2"
)

var tophubClient = resty.New().
	SetTimeout(10 * time.Second).
	SetHeaders(map[string]string{
		"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Referer":    "https://tophub.today/",
	})

// Cache for hot topics
type hotTopicsCache struct {
	data      []map[string]interface{}
	sitename  string
	logo      string
	timestamp time.Time
}

var (
	hotCacheMap   = make(map[string]*hotTopicsCache)
	hotCacheMutex sync.RWMutex
	hotCacheTTL   = 15 * time.Minute
)

// TopHubNode 预置节点
type TopHubNode struct {
	ID       int    `json:"id"`
	Name     string `json:"name"`
	Category string `json:"category"`
	Logo     string `json:"logo"`
}

var allNodes = []TopHubNode{
	// 综合
	{ID: 1, Name: "微博热搜", Category: "综合", Logo: "https://file.ipadown.com/tophub/assets/images/media/s.weibo.com.png_50x50.png"},
	{ID: 2, Name: "百度热点", Category: "综合", Logo: "https://file.ipadown.com/tophub/assets/images/media/baidu.com.png_50x50.png"},
	{ID: 6, Name: "知乎热榜", Category: "综合", Logo: "https://file.ipadown.com/tophub/assets/images/media/zhihu.com.png_50x50.png"},
	{ID: 5, Name: "微信热文", Category: "综合", Logo: "https://file.ipadown.com/tophub/assets/images/media/mp.weixin.qq.com.png_50x50.png"},
	{ID: 51, Name: "澎湃新闻", Category: "综合", Logo: "https://file.ipadown.com/tophub/assets/images/media/thepaper.cn.png_50x50.png"},
	{ID: 3608, Name: "今日头条", Category: "综合", Logo: "https://file.ipadown.com/tophub/assets/images/media/toutiao.com.png_50x50.png"},
	// 科技
	{ID: 11, Name: "36氪", Category: "科技", Logo: "https://file.ipadown.com/tophub/assets/images/media/36kr.com.png_50x50.png"},
	{ID: 32, Name: "虎嗅网", Category: "科技", Logo: "https://file.ipadown.com/tophub/assets/images/media/huxiu.com.png_50x50.png"},
	{ID: 137, Name: "少数派", Category: "科技", Logo: "https://file.ipadown.com/tophub/assets/images/media/sspai.com.png_50x50.png"},
	{ID: 13, Name: "果壳", Category: "科技", Logo: "https://file.ipadown.com/tophub/assets/images/media/guokr.com.png_50x50.png"},
	// 娱乐
	{ID: 19, Name: "哔哩哔哩", Category: "娱乐", Logo: "https://file.ipadown.com/tophub/assets/images/media/bilibili.com.png_50x50.png"},
	{ID: 221, Name: "抖音热榜", Category: "娱乐", Logo: "https://file.ipadown.com/tophub/assets/images/media/douyin.com.png_50x50.png"},
	{ID: 85, Name: "豆瓣电影", Category: "娱乐", Logo: "https://file.ipadown.com/tophub/assets/images/media/movie.douban.com.png_50x50.png"},
	// 社区
	{ID: 3, Name: "百度贴吧", Category: "社区", Logo: "https://file.ipadown.com/tophub/assets/images/media/tieba.baidu.com.png_50x50.png"},
	{ID: 42, Name: "虎扑社区", Category: "社区", Logo: "https://file.ipadown.com/tophub/assets/images/media/hupu.com.png_50x50.png"},
	{ID: 68, Name: "吾爱破解", Category: "社区", Logo: "https://file.ipadown.com/tophub/assets/images/media/52pojie.cn.png_50x50.png"},
	// 财经
	{ID: 125, Name: "知乎日报", Category: "财经", Logo: "https://file.ipadown.com/tophub/assets/images/media/zhihu.com.png_50x50.png"},
}

// GetHotTopics 获取指定节点的热搜数据
func GetHotTopics(c *gin.Context) {
	nodeid := c.Query("nodeid")
	if nodeid == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "缺少 nodeid 参数"})
		return
	}

	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	// Check cache
	cacheKey := fmt.Sprintf("%s_%s", nodeid, date)
	hotCacheMutex.RLock()
	if cached, exists := hotCacheMap[cacheKey]; exists {
		if time.Since(cached.timestamp) < hotCacheTTL {
			hotCacheMutex.RUnlock()
			c.JSON(http.StatusOK, gin.H{
				"success":  true,
				"data":     cached.data,
				"sitename": cached.sitename,
				"logo":     cached.logo,
			})
			return
		}
	}
	hotCacheMutex.RUnlock()

	// Fetch from tophub
	resp, err := tophubClient.R().
		SetFormData(map[string]string{
			"p":      "1",
			"date":   date,
			"nodeid": nodeid,
		}).
		Post("https://tophub.today/node-items-by-date")

	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "error": "获取数据失败"})
		return
	}

	var result struct {
		Status int `json:"status"`
		Data   struct {
			Items []struct {
				Title    string `json:"title"`
				Extra    string `json:"extra"`
				URL      string `json:"url"`
				Sitename string `json:"sitename"`
				Logo     string `json:"logo"`
				Time     string `json:"time"`
			} `json:"items"`
		} `json:"data"`
		Error interface{} `json:"error"`
	}

	if err := json.Unmarshal(resp.Body(), &result); err != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "error": "解析数据失败"})
		return
	}

	if result.Status != 200 || len(result.Data.Items) == 0 {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": []interface{}{}, "sitename": "", "logo": ""})
		return
	}

	var items []map[string]interface{}
	sitename := ""
	logo := ""
	for i, item := range result.Data.Items {
		if i == 0 {
			sitename = item.Sitename
			logo = item.Logo
		}
		items = append(items, map[string]interface{}{
			"rank":  i + 1,
			"title": item.Title,
			"hot":   item.Extra,
			"url":   item.URL,
			"time":  item.Time,
		})
	}

	// Update cache
	hotCacheMutex.Lock()
	hotCacheMap[cacheKey] = &hotTopicsCache{
		data:      items,
		sitename:  sitename,
		logo:      logo,
		timestamp: time.Now(),
	}
	hotCacheMutex.Unlock()

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"data":     items,
		"sitename": sitename,
		"logo":     logo,
	})
}

// GetTopHubNodes 返回所有可用数据源节点
func GetTopHubNodes(c *gin.Context) {
	category := c.Query("category")

	if category != "" {
		var filtered []TopHubNode
		for _, node := range allNodes {
			if node.Category == category {
				filtered = append(filtered, node)
			}
		}
		c.JSON(http.StatusOK, gin.H{"success": true, "data": filtered})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": allNodes})
}
