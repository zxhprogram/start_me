import 'dart:async';
import 'package:flutter/material.dart';
import '../services/icon_fetcher_service.dart';
import '../signals/app_signal.dart';

class AddIconDialog extends StatefulWidget {
  final String groupLabel;

  const AddIconDialog({super.key, required this.groupLabel});

  @override
  State<AddIconDialog> createState() => _AddIconDialogState();

  static void show(BuildContext context, String groupLabel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => AddIconDialog(groupLabel: groupLabel),
    );
  }
}

class _AddIconDialogState extends State<AddIconDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _iconTextController = TextEditingController();

  bool _isLoading = false;
  bool _hasNetworkIcon = false;
  String? _networkIconUrl;

  // Available colors for custom icon
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
  ];

  Color _selectedColor = Colors.blue;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _iconTextController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUrlChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (value.trim().isNotEmpty) {
        _fetchWebInfo(value.trim());
      }
    });
  }

  Future<void> _fetchWebInfo(String url) async {
    setState(() {
      _isLoading = true;
    });

    final data = await IconFetcherService.fetchWebInfo(url);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          // Auto-fill name
          if (_nameController.text.isEmpty) {
            _nameController.text = data.title;
          }

          // Auto-fill description
          if (_descriptionController.text.isEmpty && data.description != null) {
            _descriptionController.text = data.description!;
          }

          // Set network icon if available
          if (data.favicon != null && data.favicon!.isNotEmpty) {
            _hasNetworkIcon = true;
            _networkIconUrl = IconFetcherService.getProxyIconUrl(data.favicon!);
          } else {
            _hasNetworkIcon = false;
            _networkIconUrl = null;
            // Set default icon text from domain
            _setDefaultIconText(url);
          }
        } else {
          // Failed to fetch, use custom icon
          _hasNetworkIcon = false;
          _networkIconUrl = null;
          _setDefaultIconText(url);
        }
      });
    }
  }

  void _setDefaultIconText(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        final parts = uri.host.split('.');
        if (parts.length >= 2) {
          // Get first 1-2 characters of domain name
          final domain = parts[parts.length - 2];
          _iconTextController.text = domain
              .substring(0, domain.length.clamp(1, 2))
              .toUpperCase();
        }
      }
    } catch (e) {
      _iconTextController.text = '?';
    }
  }

  void _save() {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (url.isEmpty || name.isEmpty) {
      return;
    }

    // Build icon data
    final iconData = <String, dynamic>{
      'name': name,
      'url': url,
      'description': description,
    };

    if (_hasNetworkIcon && _networkIconUrl != null) {
      // Use network icon
      iconData['type'] = 'network';
      iconData['iconUrl'] = _networkIconUrl;
      iconData['color'] = Colors.blue; // Default color for network icons
    } else {
      // Use custom icon
      iconData['type'] = 'custom';
      iconData['color'] = _selectedColor;
      iconData['iconText'] = _iconTextController.text.isNotEmpty
          ? _iconTextController.text
                .substring(0, _iconTextController.text.length.clamp(1, 2))
                .toUpperCase()
          : '?';
    }

    addIconToGroup(widget.groupLabel, iconData);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D3A).withOpacity(0.98),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                '添加图标',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // URL Input
              _buildLabel('地址'),
              const SizedBox(height: 8),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        onChanged: _onUrlChanged,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入网址，如：https://github.com',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Name Input
              _buildLabel('名称'),
              const SizedBox(height: 8),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '输入名称',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Icon Preview
              _buildLabel('图标预览'),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildIconPreview(),
                ),
              ),
              const SizedBox(height: 20),

              // Custom Icon Options (only show if no network icon)
              if (!_hasNetworkIcon) ...[
                // Icon Color Selection
                _buildLabel('图标颜色'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(18),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Icon Text Input
                _buildLabel('图标文字（1-2字）'),
                const SizedBox(height: 8),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _iconTextController,
                    maxLength: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '如：GH',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description Input
              _buildLabel('图标信息'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '输入图标描述信息',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '保存',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '取消',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
    );
  }

  Widget _buildIconPreview() {
    if (_hasNetworkIcon && _networkIconUrl != null) {
      // Show network icon
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _networkIconUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to custom icon if network icon fails to load
            return _buildCustomIcon();
          },
        ),
      );
    } else {
      // Show custom icon
      return _buildCustomIcon();
    }
  }

  Widget _buildCustomIcon() {
    final iconText = _iconTextController.text.isNotEmpty
        ? _iconTextController.text
              .substring(0, _iconTextController.text.length.clamp(1, 2))
              .toUpperCase()
        : '?';

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _selectedColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          iconText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
