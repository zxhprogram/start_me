package database

import (
	"database/sql"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

// InitDB 初始化数据库连接
func InitDB(dbPath string) error {
	var err error
	DB, err = sql.Open("sqlite3", dbPath+"?_foreign_keys=on")
	if err != nil {
		return err
	}

	// 测试连接
	if err = DB.Ping(); err != nil {
		return err
	}

	log.Println("数据库连接成功")
	return nil
}

// CreateTables 创建数据表
func CreateTables() error {
	// 创建备忘录表
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS memos (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		content TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`

	_, err := DB.Exec(createTableSQL)
	if err != nil {
		return err
	}

	// 创建设置表
	createSettingsSQL := `
	CREATE TABLE IF NOT EXISTS settings (
		key TEXT PRIMARY KEY,
		value TEXT NOT NULL,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`

	_, err = DB.Exec(createSettingsSQL)
	if err != nil {
		return err
	}

	// 创建用户表
	createUsersSQL := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE,
		password_hash TEXT,
		github_id TEXT UNIQUE,
		github_login TEXT,
		avatar_url TEXT DEFAULT '',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`
	_, err = DB.Exec(createUsersSQL)
	if err != nil {
		return err
	}

	// 创建书签分组表
	createGroupsSQL := `
	CREATE TABLE IF NOT EXISTS bookmark_groups (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		label TEXT NOT NULL,
		icon TEXT NOT NULL DEFAULT 'folder',
		sort_order INTEGER NOT NULL DEFAULT 0,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);
	`
	_, err = DB.Exec(createGroupsSQL)
	if err != nil {
		return err
	}

	// 创建书签表
	createBookmarksSQL := `
	CREATE TABLE IF NOT EXISTS bookmarks (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		group_id INTEGER NOT NULL,
		user_id INTEGER NOT NULL,
		folder_id INTEGER DEFAULT NULL,
		name TEXT NOT NULL,
		url TEXT NOT NULL DEFAULT '',
		icon_type TEXT NOT NULL DEFAULT 'network',
		icon_url TEXT DEFAULT '',
		icon_text TEXT DEFAULT '',
		color INTEGER DEFAULT 4280391411,
		description TEXT DEFAULT '',
		sort_order INTEGER NOT NULL DEFAULT 0,
		FOREIGN KEY (group_id) REFERENCES bookmark_groups(id) ON DELETE CASCADE,
		FOREIGN KEY (user_id) REFERENCES users(id),
		FOREIGN KEY (folder_id) REFERENCES bookmark_folders(id) ON DELETE CASCADE
	);
	`
	_, err = DB.Exec(createBookmarksSQL)
	if err != nil {
		return err
	}

	// 创建书签文件夹表
	createFoldersSQL := `
	CREATE TABLE IF NOT EXISTS bookmark_folders (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		group_id INTEGER NOT NULL,
		user_id INTEGER NOT NULL,
		name TEXT NOT NULL,
		sort_order INTEGER NOT NULL DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (group_id) REFERENCES bookmark_groups(id) ON DELETE CASCADE,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);
	`
	_, err = DB.Exec(createFoldersSQL)
	if err != nil {
		return err
	}

	// 创建邮箱配置表
	createEmailConfigSQL := `
	CREATE TABLE IF NOT EXISTS email_configs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL UNIQUE,
		host TEXT NOT NULL,
		port INTEGER NOT NULL DEFAULT 995,
		username TEXT NOT NULL,
		password TEXT NOT NULL,
		use_tls INTEGER NOT NULL DEFAULT 1,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);
	`
	_, err = DB.Exec(createEmailConfigSQL)
	if err != nil {
		return err
	}

	// 创建按键统计表
	createKeystrokeSQL := `
	CREATE TABLE IF NOT EXISTS keystroke_stats (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key_name TEXT NOT NULL,
		count INTEGER NOT NULL DEFAULT 0,
		date TEXT NOT NULL,
		UNIQUE(key_name, date)
	);
	`
	_, err = DB.Exec(createKeystrokeSQL)
	if err != nil {
		return err
	}

	// 创建用户设置表
	createUserSettingsSQL := `
	CREATE TABLE IF NOT EXISTS user_settings (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		key TEXT NOT NULL,
		value TEXT NOT NULL,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(user_id, key),
		FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
	);
	`
	_, err = DB.Exec(createUserSettingsSQL)
	if err != nil {
		return err
	}

	log.Println("数据表创建成功")
	return nil
}

// CloseDB 关闭数据库连接
func CloseDB() error {
	if DB != nil {
		return DB.Close()
	}
	return nil
}
