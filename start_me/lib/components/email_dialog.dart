import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import '../services/email_service.dart';

class EmailDialog extends StatefulWidget {
  const EmailDialog({super.key});

  @override
  State<EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<EmailDialog> {
  final ScrollController _scrollController = ScrollController();
  final WebviewController _webviewController = WebviewController();

  List<Map<String, dynamic>> _emails = [];
  int _total = 0;
  int _page = 1;
  bool _isLoadingList = false;
  bool _hasMore = true;

  int? _selectedEmailId;
  Map<String, dynamic>? _emailDetail;
  bool _isLoadingDetail = false;
  bool _webviewReady = false;

  @override
  void initState() {
    super.initState();
    _initWebview();
    _loadPage(1);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initWebview() async {
    await _webviewController.initialize();
    await _webviewController.setBackgroundColor(const Color(0xFF1E1E2E));
    await _webviewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    if (mounted) {
      setState(() => _webviewReady = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _webviewController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingList &&
        _hasMore) {
      _loadPage(_page + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (_isLoadingList) return;
    setState(() => _isLoadingList = true);

    final result = await EmailService.getEmails(page: page, pageSize: 20);
    if (!mounted) return;

    final newEmails = result['emails'] as List<Map<String, dynamic>>;
    final total = result['total'] as int;

    setState(() {
      if (page == 1) {
        _emails = newEmails;
      } else {
        _emails = [..._emails, ...newEmails];
      }
      _total = total;
      _page = page;
      _hasMore = _emails.length < total;
      _isLoadingList = false;
    });
  }

  Future<void> _selectEmail(int emailId) async {
    if (_selectedEmailId == emailId) return;
    setState(() {
      _selectedEmailId = emailId;
      _emailDetail = null;
      _isLoadingDetail = true;
    });

    final detail = await EmailService.getEmailDetail(emailId);
    if (!mounted) return;

    setState(() {
      _emailDetail = detail;
      _isLoadingDetail = false;
    });

    if (detail != null && _webviewReady) {
      final body = (detail['body'] ?? '') as String;
      final html = _wrapHtml(body);
      await _webviewController.loadStringContent(html);
    }
  }

  String _wrapHtml(String body) {
    final isHtml = body.contains('<') && body.contains('>');
    final content = isHtml
        ? body
        : '<pre style="white-space:pre-wrap;word-break:break-word;font-family:sans-serif;font-size:14px;line-height:1.6;">${_escapeHtml(body)}</pre>';

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  body {
    background-color: #1E1E2E;
    color: #E0E0E0;
    font-family: -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
    font-size: 14px;
    line-height: 1.6;
    padding: 16px;
    margin: 0;
    word-break: break-word;
  }
  a { color: #64B5F6; }
  img { max-width: 100%; height: auto; }
  table { border-collapse: collapse; max-width: 100%; }
  td, th { padding: 4px 8px; }
  blockquote {
    border-left: 3px solid #444;
    margin: 8px 0;
    padding: 4px 12px;
    color: #999;
  }
  pre, code {
    background: #2D2D3A;
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 13px;
  }
</style>
</head>
<body>$content</body>
</html>''';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 1000,
          height: 650,
          color: const Color(0xFF1E1E2E),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _buildEmailList(),
                    ),
                    Container(
                      width: 1,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    Expanded(child: _buildDetailPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: Colors.blue, size: 22),
          const SizedBox(width: 10),
          const Text(
            '收件箱',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_total > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$_total 封',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailList() {
    if (_isLoadingList && _emails.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }

    if (_emails.isEmpty) {
      return Center(
        child: Text(
          '暂无邮件',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _emails.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _emails.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
              ),
            ),
          );
        }

        final email = _emails[index];
        final emailId = email['id'] as int;
        final isSelected = _selectedEmailId == emailId;

        return GestureDetector(
          onTap: () => _selectEmail(emailId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                left: isSelected
                    ? const BorderSide(color: Colors.blue, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email['from'] ?? '',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      email['date'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email['subject'] ?? '(无主题)',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((email['preview'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email['preview'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedEmailId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, size: 48, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 12),
            Text(
              '选择一封邮件查看',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isLoadingDetail) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }

    if (_emailDetail == null) {
      return Center(
        child: Text(
          '加载失败',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        ),
      );
    }

    final detail = _emailDetail!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail['subject'] ?? '(无主题)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('发件人', detail['from'] ?? ''),
              if ((detail['to'] ?? '').toString().isNotEmpty)
                _buildDetailRow('收件人', detail['to']),
              _buildDetailRow('时间', detail['date'] ?? ''),
            ],
          ),
        ),
        Expanded(
          child: _webviewReady
              ? Webview(_webviewController)
              : const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
