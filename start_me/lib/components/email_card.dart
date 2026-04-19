import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/email_service.dart';
import 'email_dialog.dart';

class EmailCard extends StatefulWidget {
  const EmailCard({super.key});

  @override
  State<EmailCard> createState() => _EmailCardState();
}

class _EmailCardState extends State<EmailCard> {
  Timer? _pollTimer;
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (emailConfigured.value) {
      _loadEmails();
    }
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (emailConfigured.value) _loadEmails();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmails() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final result = await EmailService.getEmails(page: 1, pageSize: 10);
      if (mounted) {
        emailList.value = result['emails'] as List<Map<String, dynamic>>;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _openEmailDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => const EmailDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: emailConfigured.value ? _openEmailDialog : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Watch((context) {
          final configured = emailConfigured.value;
          final loggedIn = isLoggedIn.value;
          final emails = emailList.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(emails.length),
              const SizedBox(height: 12),
              Expanded(
                child: !loggedIn
                    ? _buildPlaceholder('请先登录')
                    : !configured
                        ? _buildPlaceholder('请在设置中配置邮箱')
                        : _isLoading && emails.isEmpty
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : _error.isNotEmpty && emails.isEmpty
                                ? _buildPlaceholder(_error)
                                : emails.isEmpty
                                    ? _buildPlaceholder('暂无邮件')
                                    : _buildEmailList(emails),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        const Icon(Icons.email_outlined, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Text(
          '邮件',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        if (emailConfigured.value) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadEmails,
            child: Icon(
              Icons.refresh,
              color: _isLoading ? Colors.white24 : Colors.white54,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
      ),
    );
  }

  Widget _buildEmailList(List<Map<String, dynamic>> emails) {
    return ListView.separated(
      itemCount: emails.length > 5 ? 5 : emails.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.white.withOpacity(0.06),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final email = emails[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      email['from'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((email['preview'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
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
        );
      },
    );
  }
}
