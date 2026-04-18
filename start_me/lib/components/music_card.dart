import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../services/music_service.dart';

class MusicCard extends StatefulWidget {
  const MusicCard({super.key});

  @override
  State<MusicCard> createState() => _MusicCardState();
}

class _MusicCardState extends State<MusicCard>
    with SingleTickerProviderStateMixin {
  final Player _player = Player();
  late AnimationController _rotationController;

  List<Map<String, dynamic>> _songs = [];
  int _currentIndex = -1;
  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _initPlayer();
    _loadSongs();
  }

  void _initPlayer() {
    _positionSub = _player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      if (playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        _next();
      }
    });
  }

  Future<void> _loadSongs() async {
    final songs = await MusicService.getRandomSongs(count: 30);
    if (mounted && songs.isNotEmpty) {
      setState(() {
        _songs = songs;
        _isLoading = false;
        _currentIndex = 0;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return;
    final song = _songs[_currentIndex];
    final id = song['id'] as int;
    final url = await MusicService.getSongUrl(id);
    if (url != null && mounted) {
      await _player.open(Media(url));
    }
  }

  void _togglePlay() {
    if (_songs.isEmpty) return;
    if (_isPlaying) {
      _player.pause();
    } else {
      if (_duration == Duration.zero && _position == Duration.zero) {
        _playCurrent();
      } else {
        _player.play();
      }
    }
  }

  void _next() {
    if (_songs.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _songs.length;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _playCurrent();
  }

  void _prev() {
    if (_songs.isEmpty) return;
    setState(() {
      _currentIndex =
          _currentIndex <= 0 ? _songs.length - 1 : _currentIndex - 1;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _playCurrent();
  }

  void _shuffle() {
    if (_songs.isEmpty) return;
    setState(() {
      _songs.shuffle(Random());
      _currentIndex = 0;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    _playCurrent();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _player.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentSong =>
      (_currentIndex >= 0 && _currentIndex < _songs.length)
          ? _songs[_currentIndex]
          : null;

  @override
  Widget build(BuildContext context) {
    final song = _currentSong;
    final cover = song?['cover'] as String? ?? '';
    final name = song?['name'] as String? ?? '未知歌曲';
    final artist = song?['artist'] as String? ?? '未知歌手';
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: blurred cover
          if (cover.isNotEmpty)
            Image.network(
              cover,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A2E),
              ),
            )
          else
            Container(color: const Color(0xFF1A1A2E)),

          // Blur + dark overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),

          // Content
          _isLoading
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
              : _songs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_off,
                              color: Colors.white.withOpacity(0.3), size: 32),
                          const SizedBox(height: 8),
                          Text(
                            '暂无音乐',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          // Top: cover + info
                          Expanded(
                            child: Row(
                              children: [
                                // Rotating album cover
                                RotationTransition(
                                  turns: _rotationController,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: cover.isNotEmpty
                                          ? Image.network(
                                              '$cover?param=128y128',
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) =>
                                                      _defaultCover(),
                                            )
                                          : _defaultCover(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Song info
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        artist,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withOpacity(0.55),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Progress bar
                          Row(
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2,
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                            enabledThumbRadius: 4),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                            overlayRadius: 10),
                                    activeTrackColor:
                                        Colors.white.withOpacity(0.7),
                                    inactiveTrackColor:
                                        Colors.white.withOpacity(0.15),
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: progress,
                                    onChanged: (v) {
                                      if (_duration.inMilliseconds > 0) {
                                        _player.seek(Duration(
                                          milliseconds:
                                              (v *
                                                      _duration
                                                          .inMilliseconds)
                                                  .round(),
                                        ));
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_duration),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),

                          // Controls
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              _controlButton(
                                Icons.shuffle_rounded,
                                _shuffle,
                                size: 18,
                              ),
                              const SizedBox(width: 16),
                              _controlButton(
                                Icons.skip_previous_rounded,
                                _prev,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              // Play/Pause
                              GestureDetector(
                                onTap: _togglePlay,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _controlButton(
                                Icons.skip_next_rounded,
                                _next,
                                size: 22,
                              ),
                              const SizedBox(width: 16),
                              _controlButton(
                                Icons.replay_rounded,
                                () => _loadSongs().then((_) {
                                  if (_songs.isNotEmpty) _playCurrent();
                                }),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap,
      {double size = 20}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: Colors.white.withOpacity(0.7),
        size: size,
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: const Color(0xFF2D2D3A),
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white38, size: 28),
      ),
    );
  }
}
