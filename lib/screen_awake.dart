import 'package:wakelock_plus/wakelock_plus.dart';

/// 引用计数的屏幕常亮：播放页与投屏会话各自 acquire/release，
/// 避免 iOS 自动锁屏挂起 app 导致投屏连播的轮询定时器停摆。
class ScreenAwake {
  static int _n = 0;

  static void acquire() {
    if (_n++ == 0) WakelockPlus.enable();
  }

  static void release() {
    if (_n > 0 && --_n == 0) WakelockPlus.disable();
  }

  /// iOS 的 idleTimerDisabled 是全局开关，media_kit 的 Video 组件在
  /// 本地播放器暂停时会擅自关掉它，投屏轮询里周期性重新断言。
  static void refresh() {
    if (_n > 0) WakelockPlus.enable();
  }
}
