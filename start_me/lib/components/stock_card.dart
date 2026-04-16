import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/stock_service.dart';

class StockCard extends StatefulWidget {
  const StockCard({super.key});

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  Future<void> _loadStockData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final stocks = await StockService.fetchGlobalIndices();
      if (mounted) {
        stockData.value = stocks
            .map((s) => {
                  'name': s.name,
                  'code': s.code,
                  'price': s.price,
                  'change': s.change,
                  'changePercent': s.changePercent,
                })
            .toList();
        _hasError = false;
      }
    } catch (e) {
      print('Error loading stock data: $e');
      if (mounted) {
        _hasError = true;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getChangeColor(String change) {
    if (change.contains('+')) {
      return const Color(0xFFE91E63); // 粉红色表示上涨
    } else if (change.contains('-')) {
      return const Color(0xFF4CAF50); // 绿色表示下跌（A 股绿色表示下跌）
    }
    return Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final stocks = stockData.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and refresh button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '全球指数',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  padding: const EdgeInsets.all(4),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16, color: Colors.blue),
                  onPressed: _loadStockData,
                  tooltip: '刷新数据',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stock list - limit to 3 items to fit in card
            if (_hasError)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '数据加载失败，点击刷新',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              )
            else if (stocks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '暂无数据',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              )
            else
              ...stocks.take(3).map((stock) {
                final changeColor = _getChangeColor(stock['change'] ?? '');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${stock['name']}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${stock['code']}',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${stock['price']}',
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: changeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${stock['change']}',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    });
  }
}
