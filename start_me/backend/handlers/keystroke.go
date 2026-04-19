package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
)

func GetTopKeystrokes(c *gin.Context) {
	period := c.DefaultQuery("period", "today")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "3"))
	if limit < 1 || limit > 50 {
		limit = 3
	}

	var query string
	var args []interface{}

	if period == "today" {
		today := time.Now().Format("2006-01-02")
		query = `SELECT key_name, SUM(count) as total FROM keystroke_stats WHERE date = ? GROUP BY key_name ORDER BY total DESC LIMIT ?`
		args = []interface{}{today, limit}
	} else {
		query = `SELECT key_name, SUM(count) as total FROM keystroke_stats GROUP BY key_name ORDER BY total DESC LIMIT ?`
		args = []interface{}{limit}
	}

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "查询失败"})
		return
	}
	defer rows.Close()

	var result []gin.H
	for rows.Next() {
		var keyName string
		var count int64
		if err := rows.Scan(&keyName, &count); err != nil {
			continue
		}
		result = append(result, gin.H{"key": keyName, "count": count})
	}

	if result == nil {
		result = []gin.H{}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": result})
}

func GetAllKeystrokes(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	rows, err := database.DB.Query(
		`SELECT key_name, SUM(count) as total FROM keystroke_stats WHERE date = ? GROUP BY key_name`,
		date,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "查询失败"})
		return
	}
	defer rows.Close()

	data := make(map[string]int64)
	for rows.Next() {
		var keyName string
		var count int64
		if err := rows.Scan(&keyName, &count); err != nil {
			continue
		}
		data[keyName] = count
	}

	dateRows, err := database.DB.Query(`SELECT DISTINCT date FROM keystroke_stats ORDER BY date DESC`)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": data, "date": date, "dates": []string{}})
		return
	}
	defer dateRows.Close()

	var dates []string
	for dateRows.Next() {
		var d string
		if err := dateRows.Scan(&d); err != nil {
			continue
		}
		dates = append(dates, d)
	}
	if dates == nil {
		dates = []string{}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": data, "date": date, "dates": dates})
}

type syncRequest struct {
	Counts map[string]int64 `json:"counts" binding:"required"`
}

func SyncKeystrokes(c *gin.Context) {
	var req syncRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误"})
		return
	}

	if len(req.Counts) == 0 {
		c.JSON(http.StatusOK, gin.H{"success": true})
		return
	}

	today := time.Now().Format("2006-01-02")

	tx, err := database.DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "事务失败"})
		return
	}

	stmt, err := tx.Prepare(`
		INSERT INTO keystroke_stats (key_name, count, date) VALUES (?, ?, ?)
		ON CONFLICT(key_name, date) DO UPDATE SET count = count + excluded.count
	`)
	if err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "准备语句失败"})
		return
	}
	defer stmt.Close()

	for key, count := range req.Counts {
		if count <= 0 {
			continue
		}
		if _, err := stmt.Exec(key, count, today); err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "写入失败"})
			return
		}
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "提交失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}
