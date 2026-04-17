package models

// FetchRequest 抓取请求
type FetchRequest struct {
	URL string `json:"url" binding:"required,url"`
}

// FetchResponse 抓取响应
type FetchResponse struct {
	Success bool       `json:"success"`
	Data    *FetchData `json:"data,omitempty"`
	Error   string     `json:"error,omitempty"`
}

// FetchData 抓取的数据
type FetchData struct {
	Title       string `json:"title"`
	Favicon     string `json:"favicon,omitempty"`
	Description string `json:"description,omitempty"`
}

// TrendingRepo GitHub Trending 仓库信息
type TrendingRepo struct {
	Name        string `json:"name"`        // "owner/repo"
	Description string `json:"description"` // 仓库描述
	Language    string `json:"language"`    // 编程语言
	Stars       int    `json:"stars"`       // 总 stars
	StarsPeriod int    `json:"starsPeriod"` // 周期内新增 stars
	URL         string `json:"url"`         // 仓库链接
}

// TrendingResponse GitHub Trending 响应
type TrendingResponse struct {
	Success bool           `json:"success"`
	Data    []TrendingRepo `json:"data,omitempty"`
	Error   string         `json:"error,omitempty"`
}

// ReadmeResponse GitHub README 响应
type ReadmeResponse struct {
	Success bool   `json:"success"`
	Data    string `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}
