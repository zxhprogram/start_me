package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-resty/resty/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"start_me_backend/database"
	"start_me_backend/middleware"
	"start_me_backend/models"
)

func generateToken(userID int64) (string, error) {
	claims := jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(30 * 24 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(middleware.JWTSecret)
}

// Register 用户注册
func Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.AuthResponse{
			Success: false,
			Error:   "参数错误：" + err.Error(),
		})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "注册失败",
		})
		return
	}

	result, err := database.DB.Exec(
		"INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, datetime('now'))",
		req.Username, string(hash),
	)
	if err != nil {
		c.JSON(http.StatusConflict, models.AuthResponse{
			Success: false,
			Error:   "用户名已存在",
		})
		return
	}

	userID, _ := result.LastInsertId()
	token, err := generateToken(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "生成 token 失败",
		})
		return
	}

	// 为新用户创建默认主页分组
	database.DB.Exec(
		"INSERT INTO bookmark_groups (user_id, label, icon, sort_order) VALUES (?, '主页', 'home', 0)",
		userID,
	)

	c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		Token:   token,
		User: &models.User{
			ID:       userID,
			Username: req.Username,
		},
	})
}

// Login 用户登录
func Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.AuthResponse{
			Success: false,
			Error:   "参数错误：" + err.Error(),
		})
		return
	}

	var user models.User
	err := database.DB.QueryRow(
		"SELECT id, username, password_hash, avatar_url FROM users WHERE username = ?",
		req.Username,
	).Scan(&user.ID, &user.Username, &user.PasswordHash, &user.AvatarURL)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.AuthResponse{
			Success: false,
			Error:   "用户名或密码错误",
		})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, models.AuthResponse{
			Success: false,
			Error:   "用户名或密码错误",
		})
		return
	}

	token, err := generateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "生成 token 失败",
		})
		return
	}

	user.PasswordHash = ""
	c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		Token:   token,
		User:    &user,
	})
}

// GitHubLogin GitHub 第三方登录
func GitHubLogin(c *gin.Context) {
	var req models.GitHubLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.AuthResponse{
			Success: false,
			Error:   "参数错误",
		})
		return
	}

	// 用 GitHub token 获取用户信息
	client := resty.New()
	resp, err := client.R().
		SetHeader("Authorization", "Bearer "+req.AccessToken).
		SetHeader("Accept", "application/vnd.github.v3+json").
		SetHeader("User-Agent", "StartMe-App").
		Get("https://api.github.com/user")
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "GitHub API 请求失败",
		})
		return
	}

	var ghUser map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &ghUser); err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "解析 GitHub 用户信息失败",
		})
		return
	}

	ghID := ""
	if id, ok := ghUser["id"].(float64); ok {
		ghID = fmt.Sprintf("%d", int64(id))
	}
	ghLogin, _ := ghUser["login"].(string)
	ghAvatar, _ := ghUser["avatar_url"].(string)

	if ghID == "" || ghLogin == "" {
		c.JSON(http.StatusBadRequest, models.AuthResponse{
			Success: false,
			Error:   "无法获取 GitHub 用户信息",
		})
		return
	}

	// 查找或创建用户
	var user models.User
	err = database.DB.QueryRow(
		"SELECT id, username, github_id, github_login, avatar_url FROM users WHERE github_id = ?",
		ghID,
	).Scan(&user.ID, &user.Username, &user.GitHubID, &user.GitHubLogin, &user.AvatarURL)

	if err == sql.ErrNoRows {
		// 创建新用户
		result, err := database.DB.Exec(
			"INSERT INTO users (username, github_id, github_login, avatar_url, created_at) VALUES (?, ?, ?, ?, datetime('now'))",
			ghLogin, ghID, ghLogin, ghAvatar,
		)
		if err != nil {
			// 用户名可能重复，加后缀重试
			result, err = database.DB.Exec(
				"INSERT INTO users (username, github_id, github_login, avatar_url, created_at) VALUES (?, ?, ?, ?, datetime('now'))",
				ghLogin+"_gh", ghID, ghLogin, ghAvatar,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, models.AuthResponse{
					Success: false,
					Error:   "创建用户失败",
				})
				return
			}
		}
		user.ID, _ = result.LastInsertId()
		user.Username = ghLogin
		user.GitHubID = ghID
		user.GitHubLogin = ghLogin
		user.AvatarURL = ghAvatar

		// 为新用户创建默认主页分组
		database.DB.Exec(
			"INSERT INTO bookmark_groups (user_id, label, icon, sort_order) VALUES (?, '主页', 'home', 0)",
			user.ID,
		)
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "查询用户失败",
		})
		return
	} else {
		// 更新头像
		database.DB.Exec("UPDATE users SET avatar_url = ?, github_login = ? WHERE id = ?",
			ghAvatar, ghLogin, user.ID)
		user.AvatarURL = ghAvatar
	}

	token, err := generateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.AuthResponse{
			Success: false,
			Error:   "生成 token 失败",
		})
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		Token:   token,
		User:    &user,
	})
}

// GetProfile 获取当前用户信息
func GetProfile(c *gin.Context) {
	userID := c.GetInt64("user_id")

	var user models.User
	err := database.DB.QueryRow(
		"SELECT id, username, COALESCE(github_id,''), COALESCE(github_login,''), avatar_url FROM users WHERE id = ?",
		userID,
	).Scan(&user.ID, &user.Username, &user.GitHubID, &user.GitHubLogin, &user.AvatarURL)
	if err != nil {
		c.JSON(http.StatusNotFound, models.AuthResponse{
			Success: false,
			Error:   "用户不存在",
		})
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{
		Success: true,
		User:    &user,
	})
}
