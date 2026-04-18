import 'package:flutter/material.dart';
import '../signals/app_signal.dart';
import '../services/github_auth_service.dart';

class GitHubFeedDialog extends StatefulWidget {
  final VoidCallback onClose;

  const GitHubFeedDialog({super.key, required this.onClose});

  @override
  State<GitHubFeedDialog> createState() => _GitHubFeedDialogState();
}

class _GitHubFeedDialogState extends State<GitHubFeedDialog> {
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });
    final token = githubToken.value;
    final login = githubUser.value['login'] ?? '';
    final result = await GitHubAuthService.getUserFeed(token, login: login);
    if (mounted) {
      setState(() {
        _feedItems = result['data'] as List<Map<String, dynamic>>;
        _hasMore = result['hasMore'] == true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final token = githubToken.value;
    final login = githubUser.value['login'] ?? '';
    final nextPage = _page + 1;
    final result = await GitHubAuthService.getUserFeed(
        token, page: nextPage, login: login);
    if (mounted) {
      setState(() {
        _feedItems = [
          ..._feedItems,
          ...(result['data'] as List<Map<String, dynamic>>)
        ];
        _page = nextPage;
        _hasMore = result['hasMore'] == true;
        _isLoadingMore = false;
      });
    }
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

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'WatchEvent':
        return Colors.amber;
      case 'CreateEvent':
        return Colors.green;
      case 'ForkEvent':
        return Colors.blue;
      case 'PushEvent':
        return Colors.cyan;
      case 'PullRequestEvent':
        return Colors.purple;
      case 'IssuesEvent':
        return Colors.orange;
      case 'IssueCommentEvent':
        return Colors.teal;
      case 'ReleaseEvent':
        return Colors.pink;
      case 'DeleteEvent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'WatchEvent':
        return Icons.star;
      case 'CreateEvent':
        return Icons.add_circle_outline;
      case 'ForkEvent':
        return Icons.call_split;
      case 'PushEvent':
        return Icons.upload;
      case 'PullRequestEvent':
        return Icons.merge;
      case 'IssuesEvent':
        return Icons.bug_report;
      case 'IssueCommentEvent':
        return Icons.chat_bubble_outline;
      case 'ReleaseEvent':
        return Icons.new_releases;
      case 'DeleteEvent':
        return Icons.delete_outline;
      case 'PublicEvent':
        return Icons.public;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 800,
          height: 600,
          color: const Color(0xFF1E1E2E),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white70))
                    : _feedItems.isEmpty
                        ? Center(
                            child: Text(
                              '暂无动态',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount:
                                _feedItems.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _feedItems.length) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white54,
                                            ),
                                          )
                                        : Text(
                                            '上滑加载更多',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.3),
                                              fontSize: 11,
                                            ),
                                          ),
                                  ),
                                );
                              }
                              return _buildFeedItem(_feedItems[index]);
                            },
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
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.rss_feed, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text(
            'GitHub Feed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isLoading ? null : _loadFeed,
            child: Icon(Icons.refresh,
                color: Colors.white.withOpacity(0.5), size: 20),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> item) {
    final actor = item['actor'] ?? '';
    final actorAvatar = item['actor_avatar'] ?? '';
    final eventType = item['event_type'] ?? '';
    final eventDesc = item['event_desc'] ?? '';
    final repoName = item['repo_name'] ?? '';
    final detail = item['detail'] ?? '';
    final createdAt = item['created_at'] ?? '';
    final eventColor = _getEventColor(eventType);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ClipOval(
            child: actorAvatar.isNotEmpty
                ? Image.network(
                    actorAvatar,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 36,
                      height: 36,
                      color: Colors.grey.withOpacity(0.3),
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 20),
                    ),
                  )
                : Container(
                    width: 36,
                    height: 36,
                    color: Colors.grey.withOpacity(0.3),
                    child: const Icon(Icons.person,
                        color: Colors.white54, size: 20),
                  ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action line
                Row(
                  children: [
                    Icon(_getEventIcon(eventType),
                        color: eventColor.withOpacity(0.7), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: actor,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' $eventDesc ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: repoName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Detail (if any)
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      detail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // Time
                const SizedBox(height: 6),
                Text(
                  _timeAgo(createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
