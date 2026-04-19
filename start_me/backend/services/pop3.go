package services

import (
	"bufio"
	"crypto/tls"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net"
	"net/mail"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Email struct {
	ID      int    `json:"id"`
	From    string `json:"from"`
	Subject string `json:"subject"`
	Date    string `json:"date"`
	Preview string `json:"preview"`
}

type EmailDetail struct {
	ID      int    `json:"id"`
	From    string `json:"from"`
	To      string `json:"to"`
	Subject string `json:"subject"`
	Date    string `json:"date"`
	Body    string `json:"body"`
}

type pop3Conn struct {
	conn   net.Conn
	reader *bufio.Reader
}

func newPOP3Conn(host string, port int, useTLS bool) (*pop3Conn, error) {
	addr := fmt.Sprintf("%s:%d", host, port)
	var conn net.Conn
	var err error

	if useTLS {
		conn, err = tls.DialWithDialer(
			&net.Dialer{Timeout: 10 * time.Second},
			"tcp", addr,
			&tls.Config{ServerName: host},
		)
	} else {
		conn, err = net.DialTimeout("tcp", addr, 10*time.Second)
	}
	if err != nil {
		return nil, fmt.Errorf("连接失败: %w", err)
	}

	p := &pop3Conn{conn: conn, reader: bufio.NewReader(conn)}
	if _, err := p.readLine(); err != nil {
		conn.Close()
		return nil, err
	}
	return p, nil
}

func (p *pop3Conn) readLine() (string, error) {
	p.conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	line, err := p.reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	line = strings.TrimRight(line, "\r\n")
	if strings.HasPrefix(line, "-ERR") {
		return "", fmt.Errorf("POP3 错误: %s", line)
	}
	return line, nil
}

func (p *pop3Conn) sendCmd(cmd string) (string, error) {
	p.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	_, err := fmt.Fprintf(p.conn, "%s\r\n", cmd)
	if err != nil {
		return "", err
	}
	return p.readLine()
}

func (p *pop3Conn) readMultiLine() (string, error) {
	var sb strings.Builder
	for {
		line, err := p.readLine()
		if err != nil {
			return sb.String(), err
		}
		if line == "." {
			break
		}
		if strings.HasPrefix(line, "..") {
			line = line[1:]
		}
		sb.WriteString(line)
		sb.WriteString("\n")
	}
	return sb.String(), nil
}

func (p *pop3Conn) close() {
	p.sendCmd("QUIT")
	p.conn.Close()
}

func (p *pop3Conn) login(username, password string) error {
	if _, err := p.sendCmd("USER " + username); err != nil {
		return fmt.Errorf("用户名验证失败: %w", err)
	}
	if _, err := p.sendCmd("PASS " + password); err != nil {
		return fmt.Errorf("密码验证失败: %w", err)
	}
	return nil
}

func (p *pop3Conn) getTotal() (int, error) {
	statLine, err := p.sendCmd("STAT")
	if err != nil {
		return 0, fmt.Errorf("获取邮件数量失败: %w", err)
	}
	parts := strings.Fields(statLine)
	if len(parts) < 2 {
		return 0, fmt.Errorf("STAT 响应格式错误")
	}
	total, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, fmt.Errorf("解析邮件数量失败: %w", err)
	}
	return total, nil
}

func TestPOP3Connection(host string, port int, username, password string, useTLS bool) error {
	p, err := newPOP3Conn(host, port, useTLS)
	if err != nil {
		return err
	}
	defer p.close()
	return p.login(username, password)
}

func FetchEmails(host string, port int, username, password string, useTLS bool, page, pageSize int) ([]Email, int, error) {
	p, err := newPOP3Conn(host, port, useTLS)
	if err != nil {
		return nil, 0, err
	}
	defer p.close()

	if err := p.login(username, password); err != nil {
		return nil, 0, err
	}

	total, err := p.getTotal()
	if err != nil {
		return nil, 0, err
	}
	if total == 0 {
		return []Email{}, 0, nil
	}

	end := total - (page-1)*pageSize
	start := end - pageSize + 1
	if start < 1 {
		start = 1
	}
	if end < 1 {
		return []Email{}, total, nil
	}

	var emails []Email
	for i := end; i >= start; i-- {
		if _, err := p.sendCmd(fmt.Sprintf("RETR %d", i)); err != nil {
			continue
		}
		raw, err := p.readMultiLine()
		if err != nil {
			continue
		}
		email := parseEmail(i, raw)
		emails = append(emails, email)
	}

	sort.Slice(emails, func(a, b int) bool {
		return emails[a].ID > emails[b].ID
	})

	return emails, total, nil
}

func FetchEmailDetail(host string, port int, username, password string, useTLS bool, emailID int) (*EmailDetail, error) {
	p, err := newPOP3Conn(host, port, useTLS)
	if err != nil {
		return nil, err
	}
	defer p.close()

	if err := p.login(username, password); err != nil {
		return nil, err
	}

	if _, err := p.sendCmd(fmt.Sprintf("RETR %d", emailID)); err != nil {
		return nil, fmt.Errorf("获取邮件失败: %w", err)
	}
	raw, err := p.readMultiLine()
	if err != nil {
		return nil, fmt.Errorf("读取邮件失败: %w", err)
	}

	return parseEmailDetail(emailID, raw), nil
}

func parseEmailDetail(id int, raw string) *EmailDetail {
	msg, err := mail.ReadMessage(strings.NewReader(raw))
	if err != nil {
		return &EmailDetail{ID: id, Subject: "(解析失败)"}
	}

	subject := decodeHeader(msg.Header.Get("Subject"))
	from := decodeHeader(msg.Header.Get("From"))
	to := decodeHeader(msg.Header.Get("To"))
	dateStr := msg.Header.Get("Date")
	date := formatDate(dateStr)
	body := extractFullBody(msg)

	return &EmailDetail{
		ID:      id,
		From:    from,
		To:      to,
		Subject: subject,
		Date:    date,
		Body:    body,
	}
}

func extractFullBody(msg *mail.Message) string {
	contentType := msg.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "text/plain"
	}

	mediaType, params, err := mime.ParseMediaType(contentType)
	if err != nil {
		return readAll(msg.Body)
	}

	if strings.HasPrefix(mediaType, "multipart/") {
		return extractMultipartBody(msg.Body, params["boundary"])
	}

	return readAll(msg.Body)
}

func extractMultipartBody(body io.Reader, boundary string) string {
	if boundary == "" {
		return ""
	}
	mr := multipart.NewReader(body, boundary)
	var htmlBody, textBody string
	for {
		part, err := mr.NextPart()
		if err != nil {
			break
		}
		ct := part.Header.Get("Content-Type")
		mediaType, params, _ := mime.ParseMediaType(ct)

		if strings.HasPrefix(mediaType, "multipart/") {
			nested := extractMultipartBody(part, params["boundary"])
			if nested != "" {
				if htmlBody == "" {
					htmlBody = nested
				}
			}
			continue
		}

		if strings.Contains(ct, "text/html") {
			htmlBody = readAll(part)
		} else if strings.Contains(ct, "text/plain") || ct == "" {
			if textBody == "" {
				textBody = readAll(part)
			}
		}
	}
	if htmlBody != "" {
		return htmlBody
	}
	return textBody
}

func readAll(r io.Reader) string {
	data, err := io.ReadAll(r)
	if err != nil {
		return ""
	}
	return string(data)
}

func parseEmail(id int, raw string) Email {
	msg, err := mail.ReadMessage(strings.NewReader(raw))
	if err != nil {
		return Email{ID: id, Subject: "(解析失败)", From: "", Date: "", Preview: ""}
	}

	subject := decodeHeader(msg.Header.Get("Subject"))
	from := decodeHeader(msg.Header.Get("From"))
	dateStr := msg.Header.Get("Date")
	date := formatDate(dateStr)
	preview := extractPreview(msg, 200)

	return Email{
		ID:      id,
		From:    from,
		Subject: subject,
		Date:    date,
		Preview: preview,
	}
}

func decodeHeader(s string) string {
	dec := new(mime.WordDecoder)
	result, err := dec.DecodeHeader(s)
	if err != nil {
		return s
	}
	return result
}

func formatDate(dateStr string) string {
	t, err := mail.ParseDate(dateStr)
	if err != nil {
		return dateStr
	}
	return t.Local().Format("01-02 15:04")
}

func extractPreview(msg *mail.Message, maxLen int) string {
	contentType := msg.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "text/plain"
	}

	mediaType, params, err := mime.ParseMediaType(contentType)
	if err != nil {
		return readBodyPreview(msg.Body, maxLen)
	}

	if strings.HasPrefix(mediaType, "multipart/") {
		return extractMultipartPreview(msg.Body, params["boundary"], maxLen)
	}

	return readBodyPreview(msg.Body, maxLen)
}

func extractMultipartPreview(body io.Reader, boundary string, maxLen int) string {
	if boundary == "" {
		return ""
	}
	mr := multipart.NewReader(body, boundary)
	for {
		part, err := mr.NextPart()
		if err != nil {
			break
		}
		ct := part.Header.Get("Content-Type")
		if strings.Contains(ct, "text/plain") || ct == "" {
			return readBodyPreview(part, maxLen)
		}
	}
	return ""
}

func readBodyPreview(r io.Reader, maxLen int) string {
	buf := make([]byte, maxLen*3)
	n, _ := io.ReadFull(r, buf)
	if n == 0 {
		return ""
	}
	text := string(buf[:n])
	text = strings.TrimSpace(text)
	text = strings.ReplaceAll(text, "\r\n", " ")
	text = strings.ReplaceAll(text, "\n", " ")
	if len([]rune(text)) > maxLen {
		text = string([]rune(text)[:maxLen]) + "..."
	}
	return text
}
