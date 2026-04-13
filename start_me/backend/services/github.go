package services

import (
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/go-resty/resty/v2"
	"start_me_backend/models"
)

var githubClient = resty.New().
	SetTimeout(15 * time.Second).
	SetRetryCount(2).
	SetHeaders(map[string]string{
		"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Accept":     "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
	})

// Cache structure for trending data
type trendingCache struct {
	data      []models.TrendingRepo
	timestamp time.Time
	period    string
}

var (
	cacheMap   = make(map[string]*trendingCache)
	cacheMutex sync.RWMutex
	cacheTTL   = 1 * time.Hour
)

// GetTrendingRepos 获取 GitHub Trending 仓库列表
func GetTrendingRepos(period string) ([]models.TrendingRepo, error) {
	// Check cache first
	cacheMutex.RLock()
	if cached, exists := cacheMap[period]; exists {
		if time.Since(cached.timestamp) < cacheTTL {
			cacheMutex.RUnlock()
			return cached.data, nil
		}
	}
	cacheMutex.RUnlock()

	// Build URL based on period
	url := "https://github.com/trending"
	switch period {
	case "weekly":
		url += "?since=weekly"
	case "monthly":
		url += "?since=monthly"
	}

	// Fetch data
	resp, err := githubClient.R().Get(url)
	if err != nil {
		return nil, err
	}

	// Parse HTML
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(resp.String()))
	if err != nil {
		return nil, err
	}

	var repos []models.TrendingRepo

	// Parse each repository
	doc.Find("article.Box-row").Each(func(i int, s *goquery.Selection) {
		repo := parseRepoItem(s)
		if repo.Name != "" {
			repos = append(repos, repo)
		}
	})

	// Update cache
	cacheMutex.Lock()
	cacheMap[period] = &trendingCache{
		data:      repos,
		timestamp: time.Now(),
		period:    period,
	}
	cacheMutex.Unlock()

	return repos, nil
}

// parseRepoItem 解析单个仓库项
func parseRepoItem(s *goquery.Selection) models.TrendingRepo {
	repo := models.TrendingRepo{}

	// Parse repository name from h2 > a
	linkElem := s.Find("h2 a")
	href, exists := linkElem.Attr("href")
	if !exists || href == "" {
		return repo
	}

	// Extract owner/repo from href
	// href format: "/owner/repo"
	parts := strings.Split(strings.Trim(href, "/"), "/")
	if len(parts) >= 2 {
		repo.Name = parts[0] + "/" + parts[1]
		repo.URL = "https://github.com" + href
	}

	// Parse description
	repo.Description = strings.TrimSpace(s.Find("p.col-9").Text())

	// Parse language
	languageElem := s.Find("[itemprop='programmingLanguage']")
	if languageElem.Length() > 0 {
		repo.Language = strings.TrimSpace(languageElem.Text())
	} else {
		// Try alternative selector
		languageElem = s.Find("span.d-inline-block:contains('color:')")
		if languageElem.Length() > 0 {
			// Get the sibling span text
			text := languageElem.Next().Text()
			if text != "" {
				repo.Language = strings.TrimSpace(text)
			}
		}
	}

	// Parse stars
	starsText := s.Find("a.Link--muted").First().Text()
	repo.Stars = parseStars(starsText)

	// Parse period stars (today/this week/this month stars)
	periodStarsElem := s.Find("span.d-inline-block.float-sm-right")
	if periodStarsElem.Length() > 0 {
		starsText := periodStarsElem.Text()
		repo.StarsPeriod = parseStarsChange(starsText)
	}

	return repo
}

// parseStars 解析 stars 数字
func parseStars(text string) int {
	text = strings.TrimSpace(text)
	text = strings.ReplaceAll(text, ",", "")
	text = strings.ReplaceAll(text, "\n", "")

	// Parse k/m suffix
	if strings.HasSuffix(text, "k") {
		num, _ := strconv.ParseFloat(strings.TrimSuffix(text, "k"), 64)
		return int(num * 1000)
	}
	if strings.HasSuffix(text, "K") {
		num, _ := strconv.ParseFloat(strings.TrimSuffix(text, "K"), 64)
		return int(num * 1000)
	}
	if strings.HasSuffix(text, "m") {
		num, _ := strconv.ParseFloat(strings.TrimSuffix(text, "m"), 64)
		return int(num * 1000000)
	}
	if strings.HasSuffix(text, "M") {
		num, _ := strconv.ParseFloat(strings.TrimSuffix(text, "M"), 64)
		return int(num * 1000000)
	}

	num, _ := strconv.Atoi(text)
	return num
}

// parseStarsChange 解析周期内 stars 变化
func parseStarsChange(text string) int {
	// Text format: "+123 stars today" or "+1,234 stars this week"
	parts := strings.Fields(text)
	if len(parts) > 0 {
		stars := strings.ReplaceAll(parts[0], ",", "")
		stars = strings.ReplaceAll(stars, "+", "")
		num, _ := strconv.Atoi(stars)
		return num
	}
	return 0
}
