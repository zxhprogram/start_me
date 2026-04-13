import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../services/github_service.dart';
import '../signals/app_signal.dart';

class GitHubTrendingCard extends StatefulWidget {
  const GitHubTrendingCard({super.key});

  @override
  State<GitHubTrendingCard> createState() => _GitHubTrendingCardState();
}

class _GitHubTrendingCardState extends State<GitHubTrendingCard> {
  final List<String> _tabs = ['今日', '本周', '本月'];
  final List<String> _periods = ['daily', 'weekly', 'monthly'];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  Future<void> _fetchTrending() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final currentPeriod = githubTrendingPeriod.value;
    final repos = await GitHubService.fetchTrending(currentPeriod);

    if (mounted) {
      setState(() {
        githubTrendingData.value = {
          ...githubTrendingData.value,
          currentPeriod: repos,
        };
        _isLoading = false;
        if (repos.isEmpty) {
          _error = '暂无数据';
        }
      });
    }
  }

  void _onTabChanged(int index) {
    final newPeriod = _periods[index];
    if (newPeriod != githubTrendingPeriod.value) {
      setState(() {
        githubTrendingPeriod.value = newPeriod;
      });
      _fetchTrending();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final currentPeriod = githubTrendingPeriod.value;
      final currentTabIndex = _periods.indexOf(currentPeriod);
      final reposData = githubTrendingData.value[currentPeriod] ?? [];
      final List<TrendingRepo> repos = reposData.cast<TrendingRepo>();

      return Container(
        height: 380, // Fixed height for the card
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
                const Icon(Icons.code, color: Colors.white, size: 24),
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
                GestureDetector(
                  onTap: _isLoading ? null : _fetchTrending,
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
            const SizedBox(height: 16),

            // Tabs
            Row(
              children: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isSelected = index == currentTabIndex;
                return GestureDetector(
                  onTap: () => _onTabChanged(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Content - scrollable
            Expanded(
              child: _error != null && repos.isEmpty
                  ? _buildErrorState()
                  : repos.isEmpty && _isLoading
                  ? _buildLoadingState()
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: repos.length,
                      itemBuilder: (context, index) =>
                          _buildRepoItem(repos[index]),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white70),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? '获取失败',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _fetchTrending,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '重试',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoItem(TrendingRepo repo) {
    final languageColor = _getLanguageColor(repo.language);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  repo.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.star, color: Colors.amber.withOpacity(0.8), size: 14),
              const SizedBox(width: 4),
              Text(
                _formatStars(repo.stars),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (repo.description.isNotEmpty)
            Text(
              repo.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (repo.language.isNotEmpty) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: languageColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  repo.language,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(
                Icons.trending_up,
                color: Colors.green.withOpacity(0.8),
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                '+${_formatStars(repo.starsPeriod)}',
                style: TextStyle(
                  color: Colors.green.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    };
    return colors[language] ?? Colors.blueGrey;
  }
}
