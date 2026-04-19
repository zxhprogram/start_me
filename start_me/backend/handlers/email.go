package handlers

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"start_me_backend/database"
	"start_me_backend/services"
)

var emailEncryptKey = []byte("start_me_email_encrypt_key_2024!") // 32 bytes for AES-256

func encryptPassword(plaintext string) (string, error) {
	block, err := aes.NewCipher(emailEncryptKey)
	if err != nil {
		return "", err
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	ciphertext := aesGCM.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func decryptPassword(encrypted string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(emailEncryptKey)
	if err != nil {
		return "", err
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonceSize := aesGCM.NonceSize()
	if len(data) < nonceSize {
		return "", fmt.Errorf("密文太短")
	}
	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := aesGCM.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}

type EmailConfigRequest struct {
	Host     string `json:"host" binding:"required"`
	Port     int    `json:"port" binding:"required"`
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	UseTLS   bool   `json:"use_tls"`
}

func SaveEmailConfig(c *gin.Context) {
	userID := c.GetInt64("user_id")

	var req EmailConfigRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "参数错误"})
		return
	}

	err := services.TestPOP3Connection(req.Host, req.Port, req.Username, req.Password, req.UseTLS)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "连接测试失败: " + err.Error()})
		return
	}

	encPass, err := encryptPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "加密失败"})
		return
	}

	useTLSInt := 0
	if req.UseTLS {
		useTLSInt = 1
	}

	_, err = database.DB.Exec(`
		INSERT OR REPLACE INTO email_configs (user_id, host, port, username, password, use_tls, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
	`, userID, req.Host, req.Port, req.Username, encPass, useTLSInt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "保存失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

func GetEmailConfig(c *gin.Context) {
	userID := c.GetInt64("user_id")

	var host, username string
	var port, useTLS int
	err := database.DB.QueryRow(`
		SELECT host, port, username, use_tls FROM email_configs WHERE user_id = ?
	`, userID).Scan(&host, &port, &username, &useTLS)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": nil})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"host":     host,
			"port":     port,
			"username": username,
			"password": "****",
			"use_tls":  useTLS == 1,
		},
	})
}

func DeleteEmailConfig(c *gin.Context) {
	userID := c.GetInt64("user_id")

	_, err := database.DB.Exec(`DELETE FROM email_configs WHERE user_id = ?`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "删除失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

type emailConfig struct {
	host     string
	port     int
	username string
	password string
	useTLS   bool
}

func getUserEmailConfig(userID int64) (*emailConfig, error) {
	var host, username, encPassword string
	var port, useTLS int
	err := database.DB.QueryRow(`
		SELECT host, port, username, password, use_tls FROM email_configs WHERE user_id = ?
	`, userID).Scan(&host, &port, &username, &encPassword, &useTLS)
	if err != nil {
		return nil, fmt.Errorf("未配置邮箱")
	}

	password, err := decryptPassword(encPassword)
	if err != nil {
		return nil, fmt.Errorf("密码解密失败")
	}

	return &emailConfig{
		host:     host,
		port:     port,
		username: username,
		password: password,
		useTLS:   useTLS == 1,
	}, nil
}

func GetEmails(c *gin.Context) {
	userID := c.GetInt64("user_id")

	cfg, err := getUserEmailConfig(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 50 {
		pageSize = 20
	}

	emails, total, err := services.FetchEmails(cfg.host, cfg.port, cfg.username, cfg.password, cfg.useTLS, page, pageSize)
	if err != nil {
		errMsg := err.Error()
		if strings.Contains(errMsg, "timeout") || strings.Contains(errMsg, "连接失败") {
			errMsg = "连接邮箱服务器失败，请检查网络或配置"
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": errMsg})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"emails":    emails,
			"total":     total,
			"page":      page,
			"page_size": pageSize,
		},
	})
}

func GetEmailDetail(c *gin.Context) {
	userID := c.GetInt64("user_id")

	cfg, err := getUserEmailConfig(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	emailID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "无效的邮件 ID"})
		return
	}

	detail, err := services.FetchEmailDetail(cfg.host, cfg.port, cfg.username, cfg.password, cfg.useTLS, emailID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": detail})
}
