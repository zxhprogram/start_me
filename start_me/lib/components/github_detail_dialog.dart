import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/github_service.dart';
import '../services/github_auth_service.dart';
import '../signals/app_signal.dart';

class GitHubDetailDialog extends StatefulWidget {
  final VoidCallback onClose;

  const GitHubDetailDialog({super.key, required this.onClose});

  @override
  State<GitHubDetailDialog> createState() => _GitHubDetailDialogState();
}

class _GitHubDetailDialogState extends State<GitHubDetailDialog> {
  final List<String> _baseTabs = ['今日', '本周', '本月'];
  final List<String> _basePeriods = ['daily', 'weekly', 'monthly'];
  int _currentTabIndex = 0;
  bool _isLoadingList = false;
  bool _isLoadingReadme = false;
  Map<String, List<TrendingRepo>> _reposCache = {};
  TrendingRepo? _selectedRepo;
  String? _readmeContent;
  String? _readmeError;
  List<TrendingRepo> _myStars = [];
  bool _isLoadingStars = false;
  int _starsPage = 1;
  bool _starsHasMore = false;
  bool _isLoadingMoreStars = false;
  final ScrollController _starsScrollController = ScrollController();

  List<String> get _tabs {
    if (isGithubLoggedIn.value) {
      return [..._baseTabs, '我的 Star'];
    }
    return _baseTabs;
  }

  List<String> get _periods {
    if (isGithubLoggedIn.value) {
      return [..._basePeriods, 'my_stars'];
    }
    return _basePeriods;
  }

  bool get _isMyStarsTab => _periods[_currentTabIndex] == 'my_stars';

  @override
  void initState() {
    super.initState();
    _starsScrollController.addListener(_onStarsScroll);
    _fetchRepos();
  }

  @override
  void dispose() {
    _starsScrollController.dispose();
    super.dispose();
  }

  void _onStarsScroll() {
    if (!_isMyStarsTab || !_starsHasMore || _isLoadingMoreStars) return;
    if (_starsScrollController.position.pixels >=
        _starsScrollController.position.maxScrollExtent - 100) {
      _fetchMoreStars();
    }
  }

  Future<void> _fetchRepos() async {
    final period = _periods[_currentTabIndex];
    if (_reposCache.containsKey(period)) {
      setState(() {
        if (_reposCache[period]!.isNotEmpty && _selectedRepo == null) {
          _selectedRepo = _reposCache[period]![0];
          _fetchReadme(_selectedRepo!.name);
        }
      });
      return;
    }

    setState(() => _isLoadingList = true);

    final repos = await GitHubService.fetchTrending(period);
    if (mounted) {
      setState(() {
        _reposCache[period] = repos;
        _isLoadingList = false;
        if (repos.isNotEmpty && _selectedRepo == null) {
          _selectedRepo = repos[0];
          _fetchReadme(repos[0].name);
        }
      });
    }
  }

  Future<void> _fetchReadme(String repoName) async {
    setState(() {
      _isLoadingReadme = true;
      _readmeContent = null;
      _readmeError = null;
    });

    final content = await GitHubService.fetchRepoReadme(repoName);
    if (mounted) {
      setState(() {
        _isLoadingReadme = false;
        if (content != null) {
          _readmeContent = content;
        } else {
          _readmeError = '无法加载 README';
        }
      });
    }
  }

  void _onTabChanged(int index) {
    if (index == _currentTabIndex) return;
    setState(() {
      _currentTabIndex = index;
      _selectedRepo = null;
      _readmeContent = null;
    });
    if (_periods[index] == 'my_stars') {
      _fetchMyStars();
    } else {
      _fetchRepos();
    }
  }

  Future<void> _fetchMyStars() async {
    if (_myStars.isNotEmpty) {
      setState(() {
        if (_selectedRepo == null && _myStars.isNotEmpty) {
          _selectedRepo = _myStars[0];
          _fetchReadme(_myStars[0].name);
        }
      });
      return;
    }

    setState(() {
      _isLoadingStars = true;
      _starsPage = 1;
    });

    final token = githubToken.value;
    final result = await GitHubAuthService.getUserStars(token, page: 1);
    if (mounted) {
      final repos = _parseStarsData(result['data']);
      setState(() {
        _myStars = repos;
        _starsHasMore = result['hasMore'] == true;
        _isLoadingStars = false;
        if (repos.isNotEmpty && _selectedRepo == null) {
          _selectedRepo = repos[0];
          _fetchReadme(repos[0].name);
        }
      });
    }
  }

  Future<void> _fetchMoreStars() async {
    setState(() => _isLoadingMoreStars = true);

    final token = githubToken.value;
    final nextPage = _starsPage + 1;
    final result = await GitHubAuthService.getUserStars(token, page: nextPage);
    if (mounted) {
      final repos = _parseStarsData(result['data']);
      setState(() {
        _myStars = [..._myStars, ...repos];
        _starsPage = nextPage;
        _starsHasMore = result['hasMore'] == true;
        _isLoadingMoreStars = false;
      });
    }
  }

  List<TrendingRepo> _parseStarsData(List<Map<String, dynamic>> data) {
    return data.map((s) => TrendingRepo(
      name: s['name'] ?? '',
      description: s['description'] ?? '',
      language: s['language'] ?? '',
      stars: s['stars'] ?? 0,
      starsPeriod: 0,
      url: s['url'] ?? '',
    )).toList();
  }

  void _onRepoSelected(TrendingRepo repo) {
    setState(() => _selectedRepo = repo);
    _fetchReadme(repo.name);
  }

  List<TrendingRepo> get _currentRepos {
    if (_isMyStarsTab) return _myStars;
    return _reposCache[_periods[_currentTabIndex]] ?? [];
  }

  String _formatStars(int stars) {
    if (stars >= 1000000) return '${(stars / 1000000).toStringAsFixed(1)}M';
    if (stars >= 1000) return '${(stars / 1000).toStringAsFixed(1)}k';
    return stars.toString();
  }

  Color _getLanguageColor(String language) {
    final colors = {
      'JavaScript': Colors.yellow,
      'TypeScript': Colors.blue,
      'Python': Colors.green,
      'Java': Colors.orange,
      'Go': Colors.cyan,
      'Rust': Colors.brown,
      'C++': Colors.red,
      'C': Colors.grey,
      'C#': Colors.purple,
      'Dart': Colors.teal,
      'Vue': Colors.green.shade400,
      'Ruby': Colors.red.shade300,
      'PHP': Colors.indigo,
      'Swift': Colors.orange.shade300,
      'Kotlin': Colors.purple.shade300,
    };
    return colors[language] ?? Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 1000,
          height: 650,
          color: const Color(0xFF1E1E2E),
          child: Row(
            children: [
              _buildLeftPanel(),
              _buildRightPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.code, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'GitHub Trending',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isSelected = index == _currentTabIndex;
                return GestureDetector(
                  onTap: () => _onTabChanged(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: isSelected
                          ? const Border(
                              bottom: BorderSide(color: Colors.white, width: 2),
                            )
                          : null,
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Repo list
          Expanded(
            child: _isLoadingList || _isLoadingStars
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white70),
                  )
                : _currentRepos.isEmpty
                    ? Center(
                        child: Text(
                          '暂无数据',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5)),
                        ),
                      )
                    : ListView.builder(
                        controller: _isMyStarsTab ? _starsScrollController : null,
                        itemCount: _currentRepos.length + (_isMyStarsTab && _starsHasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _currentRepos.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: _isLoadingMoreStars
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white54,
                                        ),
                                      )
                                    : Text(
                                        '上滑加载更多',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                        ),
                                      ),
                              ),
                            );
                          }
                          final repo = _currentRepos[index];
                          final isSelected =
                              _selectedRepo?.name == repo.name;
                          return _buildRepoListItem(repo, isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoListItem(TrendingRepo repo, bool isSelected) {
    return GestureDetector(
      onTap: () => _onRepoSelected(repo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected
            ? Colors.white.withOpacity(0.1)
            : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repo.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (repo.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                repo.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (repo.language.isNotEmpty) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getLanguageColor(repo.language),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    repo.language,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Icon(Icons.star,
                    color: Colors.amber.withOpacity(0.7), size: 12),
                const SizedBox(width: 3),
                Text(
                  _formatStars(repo.stars),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
                if (repo.starsPeriod > 0) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.trending_up,
                      color: Colors.green.withOpacity(0.7), size: 12),
                  const SizedBox(width: 3),
                  Text(
                    '+${_formatStars(repo.starsPeriod)}',
                    style: TextStyle(
                      color: Colors.green.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Expanded(
      child: Container(
        color: const Color(0xFF252535),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repo header
            if (_selectedRepo != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedRepo!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedRepo!.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _selectedRepo!.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star,
                              color: Colors.amber.withOpacity(0.8),
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _formatStars(_selectedRepo!.stars),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // README content
            Expanded(
              child: _isLoadingReadme
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white70),
                    )
                  : _readmeError != null
                      ? Center(
                          child: Text(
                            _readmeError!,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5)),
                          ),
                        )
                      : _readmeContent != null
                          ? Markdown(
                              data: _readmeContent!,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                h1: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                                h2: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                                h3: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                                h4: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                p: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    height: 1.6),
                                a: const TextStyle(
                                    color: Colors.lightBlueAccent),
                                code: TextStyle(
                                  color: Colors.greenAccent.shade200,
                                  backgroundColor:
                                      Colors.black.withOpacity(0.3),
                                  fontSize: 13,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                codeblockPadding:
                                    const EdgeInsets.all(12),
                                listBullet: TextStyle(
                                    color:
                                        Colors.white.withOpacity(0.7)),
                                blockquoteDecoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                        color: Colors.white
                                            .withOpacity(0.3),
                                        width: 3),
                                  ),
                                ),
                                blockquotePadding:
                                    const EdgeInsets.only(left: 12),
                                horizontalRuleDecoration:
                                    BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                        color: Colors.white
                                            .withOpacity(0.2)),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                '选择一个项目查看 README',
                                style: TextStyle(
                                    color:
                                        Colors.white.withOpacity(0.4)),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
