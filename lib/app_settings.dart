import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置：收藏夹关键字、观看时长限制、预设体验模式。
/// main 启动时 load()，之后内存同步读，setter 落盘并通知。
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings i = AppSettings._();

  /// 收藏夹标题前缀关键字，命中任一即展示
  List<String> kidKeywords = const ['儿童'];

  /// 连续观看多少分钟必须休息，0=不限制
  int restAfterMin = 30;

  /// 每次休息多少分钟
  int restMin = 10;

  /// 每日观看总时长上限（分钟），0=不限制
  int dailyLimitMin = 0;

  /// 预设内容体验模式（未配置收藏夹时快速体验）
  bool trialMode = false;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    kidKeywords = p.getStringList('kid_keywords') ?? const ['儿童'];
    restAfterMin = p.getInt('st_rest_after_min') ?? 30;
    restMin = p.getInt('st_rest_min') ?? 10;
    dailyLimitMin = p.getInt('st_daily_limit_min') ?? 0;
    trialMode = p.getBool('trial_mode') ?? false;
  }

  Future<void> setKidKeywords(List<String> v) async {
    if (v.isEmpty) return;
    kidKeywords = List.unmodifiable(v);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('kid_keywords', kidKeywords);
  }

  Future<void> setRestAfterMin(int v) async {
    restAfterMin = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('st_rest_after_min', v);
  }

  Future<void> setRestMin(int v) async {
    restMin = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('st_rest_min', v);
  }

  Future<void> setDailyLimitMin(int v) async {
    dailyLimitMin = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('st_daily_limit_min', v);
  }

  Future<void> setTrialMode(bool v) async {
    trialMode = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('trial_mode', v);
  }
}
