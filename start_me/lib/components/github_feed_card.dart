import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/github_auth_service.dart';
import 'github_feed_dialog.dart';

class GitHubFeedCard extends StatefulWidget {
  const GitHubFeedCard({super.key});

  @override
  State<GitHubFeedCard> createState() => _GitHubFeedCardState();
}

class _GitHubFeedCardState extends State<GitHubFeedCard> {
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (isGithubLoggedIn.value) {
      _loadFeed();
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    final token = githubToken.value;
    final login = githubUser.value['login'] ?? '';
    final result = await GitHubAuthService.getUserFeed(token, login: login);
    if (mounted) {
      setState(() {
        _feedItems = result['data'] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  void _openDetailDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GitHubFeedDialog(
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  String _timeAgo(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 30) return '${diff.inDays}天前';
      return '${(diff.inDays / 30).floor()}个月前';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final loggedIn = isGithubLoggedIn.value;

      return GestureDetector(
        onTap: loggedIn ? _openDetailDialog : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D3A).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.rss_feed, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'GitHub Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (loggedIn)
                    GestureDetector(
                      onTap: _isLoading ? null : _loadFeed,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: Colors.white.withOpacity(0.6),
                              size: 20,
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Content
              Expanded(
                child: !loggedIn
                    ? _buildNotLoggedIn()
                    : _isLoading && _feedItems.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white70))
                        : _feedItems.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无动态',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _feedItems.length > 4
                                    ? 4
                                    : _feedItems.length,
                                itemBuilder: (context, index) =>
                                    _buildFeedItem(_feedItems[index]),
                              ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.login,
              color: Colors.white.withOpacity(0.4), size: 32),
          const SizedBox(height: 8),
          Text(
            '请先在设置中登录 GitHub',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> item) {
    final actor = item['actor'] ?? '';
    final actorAvatar = item['actor_avatar'] ?? '';
    final eventDesc = item['event_desc'] ?? '';
    final repoName = item['repo_name'] ?? '';
    final createdAt = item['created_at'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Avatar
          ClipOval(
            child: actorAvatar.isNotEmpty
                ? Image.network(
                    actorAvatar,
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 22,
                      height: 22,
                      color: Colors.grey.withOpacity(0.3),
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 14),
                    ),
                  )
                : Container(
                    width: 22,
                    height: 22,
                    color: Colors.grey.withOpacity(0.3),
                    child: const Icon(Icons.person,
                        color: Colors.white54, size: 14),
                  ),
          ),
          const SizedBox(width: 8),
          // Text
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: actor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: ' $eventDesc ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: repoName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _timeAgo(createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
