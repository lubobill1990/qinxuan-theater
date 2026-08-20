@Tags(['golden'])
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bilibili_kid_viewer/pages/kid_lock_guide_page.dart';
import 'package:bilibili_kid_viewer/pages/login_page.dart';
import 'package:bilibili_kid_viewer/pages/main_shell.dart';

import 'harness.dart';

Future<void> snap(WidgetTester tester, String name) => expectLater(
    find.byType(CupertinoApp), matchesGoldenFile('goldens/$name.png'));

void main() {
  setUp(() async {
    await setUpScreenshotEnv();
  });

  testWidgets('登录 FRE 三步 + 二维码 @ iPhone', (tester) async {
    await pumpApp(tester, LoginPage(onLoggedIn: () {}));
    await realSettle(tester);
    await snap(tester, 'login_fre_1_iphone');

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await snap(tester, 'login_fre_2_iphone');

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await snap(tester, 'login_fre_3_iphone');

    await tester.tap(find.text('去扫码登录'));
    await realSettle(tester);
    await snap(tester, 'login_qr_iphone');

    await drain(tester);
  });

  testWidgets('登录 FRE @ iPad', (tester) async {
    await pumpApp(tester, LoginPage(onLoggedIn: () {}), size: ipadPortrait);
    await realSettle(tester);
    await snap(tester, 'login_fre_1_ipad');
    await drain(tester);
  });

  testWidgets('首页 @ iPhone', (tester) async {
    await pumpApp(tester, MainShell(onLogout: () {}));
    await realSettle(tester);
    await snap(tester, 'home_iphone');
    await drain(tester);
  });

  testWidgets('首页 @ iPad 竖屏/横屏', (tester) async {
    await pumpApp(tester, MainShell(onLogout: () {}), size: ipadPortrait);
    await realSettle(tester);
    await snap(tester, 'home_ipad');

    await pumpApp(tester, MainShell(onLogout: () {}), size: ipadLandscape);
    await realSettle(tester);
    await snap(tester, 'home_ipad_landscape');
    await drain(tester);
  });

  testWidgets('搜索：键盘上方空态 + 结果 @ iPhone', (tester) async {
    await pumpApp(tester, MainShell(onLogout: () {}), keyboardInset: 300);
    await realSettle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.search));
    await realSettle(tester, rounds: 6);
    await snap(tester, 'search_empty_keyboard_iphone');

    await tester.enterText(find.byType(CupertinoSearchTextField), '佩奇');
    await realSettle(tester, rounds: 6);
    await snap(tester, 'search_results_iphone');
    await drain(tester);
  });

  testWidgets('历史页空态 @ iPhone', (tester) async {
    await pumpApp(tester, MainShell(onLogout: () {}));
    await realSettle(tester);
    await tester.tap(find.text('历史'));
    await realSettle(tester, rounds: 4);
    await snap(tester, 'history_empty_iphone');
    await drain(tester);
  });

  testWidgets('引导式访问教程三步 @ iPhone', (tester) async {
    await pumpApp(tester, const KidLockGuidePage(active: false));
    await realSettle(tester);
    await snap(tester, 'kidlock_guide_1_iphone');

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await realSettle(tester, rounds: 4);
    await snap(tester, 'kidlock_guide_2_iphone');

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await realSettle(tester, rounds: 4);
    await snap(tester, 'kidlock_guide_3_iphone');
  });

  testWidgets('引导式访问教程 @ iPad', (tester) async {
    await pumpApp(tester, const KidLockGuidePage(active: false),
        size: ipadPortrait);
    await realSettle(tester);
    await snap(tester, 'kidlock_guide_1_ipad');
  });
}
