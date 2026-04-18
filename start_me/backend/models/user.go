package models

import "time"

type User struct {
	ID           int64     `json:"id"`
	Username     string    `json:"username"`
	PasswordHash string    `json:"-"`
	GitHubID     string    `json:"github_id,omitempty"`
	GitHubLogin  string    `json:"github_login,omitempty"`
	AvatarURL    string    `json:"avatar_url"`
	CreatedAt    time.Time `json:"created_at"`
}

type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=2,max=32"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type GitHubLoginRequest struct {
	AccessToken string `json:"access_token" binding:"required"`
}

type AuthResponse struct {
	Success bool   `json:"success"`
	Token   string `json:"token,omitempty"`
	User    *User  `json:"user,omitempty"`
	Error   string `json:"error,omitempty"`
}
