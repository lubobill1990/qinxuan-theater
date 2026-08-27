import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'cast/dlna_cast.dart';
import 'kid_lock.dart';
import 'pages/lock_page.dart';

enum LockKind { rest, daily }

/// 观看时长统计与限制：只有实际播放中才计时——
/// 本地播放器在播，或电视端投屏真的在播（暂停/加载/播完都不算）。
/// 连续观看到设定值弹休息锁（倒计时结束自动解锁），
/// 当日总时长到上限弹每日锁（只能家长 PIN 解锁）。
class ScreenTime extends ChangeNotifier {
  ScreenTime._();
  static final ScreenTime i = ScreenTime._();

  GlobalKey<NavigatorState>? _navKey;
  Timer? _timer;

  bool _localPlaying = false;

  /// 锁定时需要暂停的本地播放器（PlayerPage 注册 _player.pause）
  final Set<VoidCallback> pauseHandlers = {};

  int continuousSec = 0;
  int todaySec = 0;
  int _idleSec = 0;
  String _dayKey = '';
  bool dailyUnlocked = false;

  LockKind? lock;
  int restRemainSec = 0;

  bool _dirty = false;
  int _sinceSave = 0;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navKey = navKey;
    final p = await SharedPreferences.getInstance();
    _dayKey = p.getString('st_day') ?? '';
    todaySec = p.getInt('st_today_sec') ?? 0;
    dailyUnlocked = p.getBool('st_daily_unlocked') ?? false;
    _rollDay(_fmtDay(DateTime.now()));
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => tick(DateTime.now()));
  }

  void setLocalPlaying(bool v) => _localPlaying = v;

  @visibleForTesting
  void resetForTest() {
    _timer?.cancel();
    _timer = null;
    _localPlaying = false;
    continuousSec = 0;
    todaySec = 0;
    _idleSec = 0;
    _dayKey = '';
    dailyUnlocked = false;
    lock = null;
    restRemainSec = 0;
    _lockRoute = null;
    _dirty = false;
    _sinceSave = 0;
  }

  static String _fmtDay(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _rollDay(String day) {
    if (day == _dayKey) return;
    _dayKey = day;
    todaySec = 0;
    dailyUnlocked = false;
    _dirty = true;
  }

  @visibleForTesting
  void tick(DateTime now) {
    _rollDay(_fmtDay(now));
    final s = AppSettings.i;
    if (lock == LockKind.rest) {
      if (--restRemainSec <= 0) _unlock();
      notifyListeners();
      _maybeSave();
      return;
    }
    final watching =
        lock == null && (_localPlaying || CastSession.i.playing);
    if (watching) {
      continuousSec++;
      todaySec++;
      _idleSec = 0;
      _dirty = true;
      if (s.dailyLimitMin > 0 &&
          !dailyUnlocked &&
          todaySec >= s.dailyLimitMin * 60) {
        _lock(LockKind.daily);
      } else if (s.restAfterMin > 0 && continuousSec >= s.restAfterMin * 60) {
        restRemainSec = s.restMin * 60;
        _lock(LockKind.rest);
      }
      notifyListeners();
    } else if (continuousSec > 0 && lock == null) {
      // 自然停播满一个休息时长，视为已休息过
      if (++_idleSec >= s.restMin * 60) continuousSec = 0;
    }
    _maybeSave();
  }

  Route? _lockRoute;

  void _lock(LockKind kind) {
    lock = kind;
    for (final h in pauseHandlers) {
      h();
    }
    // 电视端不受锁定页控制，暂停指令还可能被遥控器恢复，直接停投
    if (CastSession.i.active) CastSession.i.stop();
    final nav = _navKey?.currentState;
    if (nav != null && _lockRoute == null) {
      final route = CupertinoPageRoute<void>(
          fullscreenDialog: true, builder: (_) => const LockPage());
      _lockRoute = route;
      nav.push(route);
    }
    _save();
  }

  void _unlock() {
    lock = null;
    continuousSec = 0;
    _idleSec = 0;
    restRemainSec = 0;
    final r = _lockRoute;
    _lockRoute = null;
    if (r != null && r.isActive) _navKey?.currentState?.removeRoute(r);
    notifyListeners();
  }

  /// 锁定页上的家长解锁：休息锁提前放行；每日锁解除后当天不再限制。
  Future<void> parentUnlock(BuildContext context) async {
    if (!await KidLock.i.verifyParent(context)) return;
    if (lock == LockKind.daily) {
      dailyUnlocked = true;
      _dirty = true;
    }
    _unlock();
    _save();
  }

  void _maybeSave() {
    if (++_sinceSave >= 15) _save();
  }

  Future<void> _save() async {
    _sinceSave = 0;
    if (!_dirty) return;
    _dirty = false;
    final p = await SharedPreferences.getInstance();
    await p.setString('st_day', _dayKey);
    await p.setInt('st_today_sec', todaySec);
    await p.setBool('st_daily_unlocked', dailyUnlocked);
  }
}
