import 'dart:convert';
import 'package:http/http.dart' as http;

/// 股票/指数信息数据类
class StockInfo {
  final String name;      // 名称
  final String code;      // 代码
  final String price;     // 当前价格
  final String change;    // 涨跌幅
  final String changePercent; // 涨跌额

  StockInfo({
    required this.name,
    required this.code,
    required this.price,
    required this.change,
    required this.changePercent,
  });

  factory StockInfo.fromJson(Map<String, dynamic> json) {
    return StockInfo(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      price: json['price'] ?? '0.00',
      change: json['change'] ?? '0',
      changePercent: json['changePercent'] ?? '0%',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'price': price,
      'change': change,
      'changePercent': changePercent,
    };
  }
}

/// 股票数据服务
class StockService {
  static const String _baseUrl = 'https://quote.fx678.com/exchange/GJZS';

  /// 获取全球股票指数数据
  /// 由于目标网站是 HTML 页面，这里使用模拟数据进行演示
  /// 实际项目中可以通过后端 API 获取真实数据
  static Future<List<StockInfo>> fetchGlobalIndices() async {
    try {
      // 由于跨 CORS 限制，前端无法直接获取网页内容
      // 这里使用模拟数据，实际项目中应该通过后端 API 获取
      final mockData = [
        {'name': '日经 225', 'code': 'NIKKI', 'price': '58134.24', 'change': '+0.44%', 'changePercent': '+0.44%'},
        {'name': '恒生指数', 'code': 'HSI', 'price': '25947.32', 'change': '+0.29%', 'changePercent': '+0.29%'},
        {'name': '道琼斯', 'code': 'DJIA', 'price': '48535.99', 'change': '+0.66%', 'changePercent': '+0.66%'},
        {'name': '标普 500', 'code': 'SP500', 'price': '6967.39', 'change': '+1.18%', 'changePercent': '+1.18%'},
        {'name': '德国 DAX', 'code': 'DAX', 'price': '24061.14', 'change': '+0.07%', 'changePercent': '+0.07%'},
      ];

      return mockData.map((item) => StockInfo.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching stock data: $e');
      return [];
    }
  }

  /// 从 HTML 内容解析股票数据
  /// 实际项目中可以调用后端 API 解析 HTML 后返回
  static List<StockInfo> parseFromHtml(String htmlContent) {
    final stocks = <StockInfo>[];

    try {
      // 解析 HTML 中的股票数据
      // 这里使用简单的正则表达式匹配
      // 实际项目中应该使用更健壮的 HTML 解析器

      // 匹配格式：名称、代码、价格、涨跌幅
      final pattern = RegExp(r'([^\d]+?)(\d+\.?\d*)\s*\(([^)]+)\)');
      final matches = pattern.allMatches(htmlContent);

      for (final match in matches) {
        stocks.add(StockInfo(
          name: match.group(1)?.trim() ?? '',
          code: match.group(2)?.trim() ?? '',
          price: match.group(3)?.trim() ?? '0',
          change: match.group(4)?.trim() ?? '0',
          changePercent: match.group(4)?.trim() ?? '0%',
        ));
      }
    } catch (e) {
      print('Error parsing HTML: $e');
    }

    return stocks;
  }
}
