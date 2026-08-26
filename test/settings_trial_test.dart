import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bilibili_kid_viewer/app_settings.dart';
import 'package:bilibili_kid_viewer/pages/lock_page.dart';
import 'package:bilibili_kid_viewer/pages/main_shell.dart';
import 'package:bilibili_kid_viewer/pages/settings_page.dart';
import 'package:bilibili_kid_viewer/screen_time.dart';

import 'fake_http.dart';
import 'harness.dart';

void main() {
  setUp(() async {
    await setUpTestEnv(prefs: {'kid_pin': '1234'});
    ScreenTime.i.resetForTest();
  });

  Future<void> enterPin(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(CupertinoTextField), pin);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  }

  group('锁定页', () {
    testWidgets('休息锁显示倒计时且不可返回', (tester) async {
      ScreenTime.i
        ..lock = LockKind.rest
        ..restRemainSec = 90;
      await pumpApp(tester, const LockPage());
      await tester.pump();

      expect(find.text('休息一下'), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('倒计时结束自动继续'), findsOneWidget);
      expect(find.text('家长解锁'), findsOneWidget);
      final pop = tester.widget<PopScope>(
          find.byWidgetPredicate((w) => w is PopScope));
      expect(pop.canPop, isFalse);
    });

    testWidgets('每日锁不显示倒计时', (tester) async {
      ScreenTime.i.lock = LockKind.daily;
      await pumpApp(tester, const LockPage());
      await tester.pump();

      expect(find.text('今天看够啦'), findsOneWidget);
      expect(find.text('倒计时结束自动继续'), findsNothing);
      expect(find.text('家长解锁'), findsOneWidget);
    });
  });

  group('设置页', () {
    testWidgets('关键字子页过 PIN 后可增删，至少保留一个', (tester) async {
      await pumpApp(tester, SettingsPage(onLogout: () {}));
      await settle(tester);
      expect(find.text('观看时长限制'), findsOneWidget);

      await tester.tap(find.text('收藏夹关键字'));
      await tester.pumpAndSettle();
      await enterPin(tester, '1234');
      expect(find.text('添加关键字'), findsOneWidget);

      await tester.tap(find.text('添加关键字'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '亲选');
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(AppSettings.i.kidKeywords, ['儿童', '亲选']);

      await tester.tap(find.byIcon(CupertinoIcons.minus_circle_fill).first);
      await tester.pumpAndSettle();
      expect(AppSettings.i.kidKeywords, ['亲选']);
      expect(find.byIcon(CupertinoIcons.minus_circle_fill), findsNothing,
          reason: '只剩一个关键字时不能删除');
    });

    testWidgets('PIN 错误进不了子页', (tester) async {
      await pumpApp(tester, SettingsPage(onLogout: () {}));
      await settle(tester);

      await tester.tap(find.text('收藏夹关键字'));
      await tester.pumpAndSettle();
      await enterPin(tester, '9999');
      expect(find.text('添加关键字'), findsNothing);
    });

    testWidgets('时长子页显示今日已观看与三项设置', (tester) async {
      ScreenTime.i.todaySec = 65 * 60;
      await pumpApp(tester, SettingsPage(onLogout: () {}));
      await settle(tester);

      await tester.tap(find.text('观看时长限制'));
      await tester.pumpAndSettle();
      await enterPin(tester, '1234');

      expect(find.text('今日已观看'), findsOneWidget);
      expect(find.text('1 小时 5 分钟'), findsOneWidget);
      expect(find.text('连看多久必须休息'), findsOneWidget);
      expect(find.text('每次休息时长'), findsOneWidget);
      expect(find.text('每日观看上限'), findsOneWidget);
    });
  });

  group('预设体验模式', () {
    testWidgets('无收藏夹时可进入体验并退出', (tester) async {
      FakeBili.folders.clear();
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);

      expect(find.textContaining('没有找到'), findsOneWidget);
      expect(find.text('查看使用说明'), findsOneWidget);

      await tester.tap(find.text('先用预设内容快速体验'));
      await settle(tester);
      await settle(tester);

      expect(find.text('正在体验预设内容'), findsOneWidget);
      expect(find.text('亲选动画'), findsOneWidget);
      expect(find.textContaining('体验·经典动画合集'), findsOneWidget);
      expect(AppSettings.i.trialMode, isTrue);

      await tester.tap(find.text('退出体验'));
      await settle(tester);
      await settle(tester);

      expect(find.text('正在体验预设内容'), findsNothing);
      expect(find.textContaining('没有找到'), findsOneWidget);
      expect(AppSettings.i.trialMode, isFalse);
    });
  });
}
