package services

import (
	"net/url"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/go-resty/resty/v2"
	"start_me_backend/models"
)

var client = resty.New().
	SetTimeout(10 * time.Second).
	SetRetryCount(2)

// FetchWebInfo 抓取网页信息
func FetchWebInfo(targetURL string) (*models.FetchData, error) {
	// 确保 URL 有协议
	if !strings.HasPrefix(targetURL, "http://") && !strings.HasPrefix(targetURL, "https://") {
		targetURL = "https://" + targetURL
	}

	resp, err := client.R().Get(targetURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(resp.String()))
	if err != nil {
		return nil, err
	}

	data := &models.FetchData{}

	// 解析 title
	title := doc.Find("title").Text()
	if title == "" {
		title = doc.Find("h1").First().Text()
	}
	data.Title = strings.TrimSpace(title)

	// 解析 description
	description, _ := doc.Find(`meta[name="description"]`).Attr("content")
	if description == "" {
		description, _ = doc.Find(`meta[property="og:description"]`).Attr("content")
	}
	data.Description = strings.TrimSpace(description)

	// 解析 favicon
	favicon := ""
	doc.Find("link").Each(func(i int, s *goquery.Selection) {
		rel, exists := s.Attr("rel")
		if exists && (strings.Contains(rel, "icon") || rel == "shortcut icon") {
			href, exists := s.Attr("href")
			if exists {
				favicon = href
				return
			}
		}
	})

	// 如果没有找到 favicon，使用默认路径
	if favicon == "" {
		favicon = "/favicon.ico"
	}

	// 将相对路径转换为绝对路径
	if !strings.HasPrefix(favicon, "http://") && !strings.HasPrefix(favicon, "https://") {
		parsedURL, err := url.Parse(targetURL)
		if err == nil {
			if strings.HasPrefix(favicon, "/") {
				favicon = parsedURL.Scheme + "://" + parsedURL.Host + favicon
			} else {
				favicon = parsedURL.Scheme + "://" + parsedURL.Host + "/" + favicon
			}
		}
	}

	data.Favicon = favicon

	return data, nil
}

// FetchIcon 获取图标内容
func FetchIcon(iconURL string) ([]byte, string, error) {
	resp, err := client.R().Get(iconURL)
	if err != nil {
		return nil, "", err
	}

	contentType := resp.Header().Get("Content-Type")
	return resp.Body(), contentType, nil
}
