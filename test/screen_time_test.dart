import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bilibili_kid_viewer/app_settings.dart';
import 'package:bilibili_kid_viewer/screen_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScreenTime st;
  var day = DateTime(2026, 1, 1, 10);

  Future<void> prepare({
    int restAfterMin = 0,
    int restMin = 10,
    int dailyLimitMin = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.i.load();
    await AppSettings.i.setRestAfterMin(restAfterMin);
    await AppSettings.i.setRestMin(restMin);
    await AppSettings.i.setDailyLimitMin(dailyLimitMin);
    st = ScreenTime.i..resetForTest();
    day = DateTime(2026, 1, 1, 10);
    // 先走一拍确立当天，避免测试内首拍触发跨天重置
    st.tick(day);
  }

  void ticks(int n) {
    for (var i = 0; i < n; i++) {
      day = day.add(const Duration(seconds: 1));
      st.tick(day);
    }
  }

  test('连看到设定时长触发休息锁，倒计时结束自动解锁', () async {
    await prepare(restAfterMin: 1, restMin: 1);
    st.setLocalPlaying(true);
    ticks(59);
    expect(st.lock, isNull);
    ticks(1);
    expect(st.lock, LockKind.rest);
    expect(st.restRemainSec, 60);
    expect(st.todaySec, 60);
    // 锁定期间不再计时，倒计时走完自动解锁并清零连续时长
    ticks(60);
    expect(st.lock, isNull);
    expect(st.continuousSec, 0);
    expect(st.todaySec, 60);
  });

  test('自然停播满一个休息时长后重置连续计时', () async {
    await prepare(restAfterMin: 1, restMin: 1);
    st.setLocalPlaying(true);
    ticks(30);
    expect(st.continuousSec, 30);
    st.setLocalPlaying(false);
    ticks(59);
    expect(st.continuousSec, 30);
    ticks(1);
    expect(st.continuousSec, 0);
    // 重新播放从头累计
    st.setLocalPlaying(true);
    ticks(59);
    expect(st.lock, isNull);
    ticks(1);
    expect(st.lock, LockKind.rest);
  });

  test('每日上限触发每日锁且不会自动解锁', () async {
    await prepare(dailyLimitMin: 1);
    st.setLocalPlaying(true);
    ticks(60);
    expect(st.lock, LockKind.daily);
    ticks(600);
    expect(st.lock, LockKind.daily);
    expect(st.todaySec, 60);
  });

  test('家长解锁当日后不再触发每日锁', () async {
    await prepare(dailyLimitMin: 1);
    st.setLocalPlaying(true);
    st.dailyUnlocked = true;
    ticks(120);
    expect(st.lock, isNull);
    expect(st.todaySec, 120);
  });

  test('跨天重置当日时长与解锁状态', () async {
    await prepare(dailyLimitMin: 1);
    st.setLocalPlaying(true);
    st.dailyUnlocked = true;
    ticks(90);
    expect(st.todaySec, 90);
    day = DateTime(2026, 1, 2, 8);
    st.tick(day);
    expect(st.todaySec, 1);
    expect(st.dailyUnlocked, isFalse);
  });

  test('都不限制时只累计不触锁', () async {
    await prepare();
    st.setLocalPlaying(true);
    ticks(3600);
    expect(st.lock, isNull);
    expect(st.continuousSec, 3600);
    expect(st.todaySec, 3600);
  });
}
