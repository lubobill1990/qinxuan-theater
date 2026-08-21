import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bilibili_kid_viewer/pages/kid_lock_guide_page.dart';
import 'package:bilibili_kid_viewer/pages/login_page.dart';
import 'package:bilibili_kid_viewer/pages/main_shell.dart';

import 'fake_http.dart';
import 'harness.dart';

void main() {
  setUp(() async {
    await setUpTestEnv();
  });

  group('登录 FRE', () {
    testWidgets('翻页到最后一页显示二维码，跳过可直达', (tester) async {
      await pumpApp(tester, LoginPage(onLoggedIn: () {}));
      await settle(tester);

      expect(find.text('给孩子的专属小剧场'), findsOneWidget);
      expect(find.text('下一步'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('家长掌控内容'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('去扫码登录'), findsOneWidget);

      await tester.tap(find.text('去扫码登录'));
      await tester.pumpAndSettle();
      expect(find.text('登录哔哩哔哩账号'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);
      expect(find.text('跳过'), findsNothing);

      await tester.pumpWidget(const SizedBox()); // 释放二维码轮询 Timer
    });

    testWidgets('跳过按钮直达二维码页', (tester) async {
      await pumpApp(tester, LoginPage(onLoggedIn: () {}));
      await settle(tester);
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      expect(find.text('登录哔哩哔哩账号'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final entry in {'iPhone': phonePortrait, 'iPad': ipadPortrait}.entries) {
      testWidgets('${entry.key}: 底部按钮文字完整显示不裁切', (tester) async {
        await pumpApp(tester, LoginPage(onLoggedIn: () {}), size: entry.value);
        await settle(tester);

        final text = find.text('下一步');
        final button = find.ancestor(
            of: text, matching: find.byType(CupertinoButton));
        final tRect = tester.getRect(text);
        final bRect = tester.getRect(button);
        expect(tRect.top, greaterThanOrEqualTo(bRect.top),
            reason: '文字顶部超出按钮');
        expect(tRect.bottom, lessThanOrEqualTo(bRect.bottom),
            reason: '文字底部被按钮裁切');

        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('主壳与搜索', () {
    testWidgets('键盘弹出时搜索框贴在键盘上方（不被双倍顶起）', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}), keyboardInset: 300);
      await settle(tester);

      await tester.tap(find.byIcon(CupertinoIcons.search));
      await tester.pumpAndSettle();

      final field = find.byType(CupertinoSearchTextField);
      expect(field, findsOneWidget);
      final rect = tester.getRect(field);
      final keyboardTop = phonePortrait.height - 300;
      expect(rect.bottom, lessThanOrEqualTo(keyboardTop),
          reason: '搜索框不应被键盘遮挡');
      expect(rect.bottom, greaterThan(keyboardTop - 80),
          reason: '搜索框应贴近键盘顶部，而不是被顶到屏幕中间');
    });

    testWidgets('搜索按标题过滤视频', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);

      await tester.tap(find.byIcon(CupertinoIcons.search));
      await tester.pumpAndSettle();
      expect(find.text('输入关键词搜索视频'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), '佩奇');
      await settle(tester);
      expect(find.textContaining('小猪佩奇'), findsNWidgets(2));
      expect(find.textContaining('超级飞侠'), findsNothing);

      await tester.enterText(find.byType(CupertinoSearchTextField), '不存在的关键词');
      await settle(tester);
      expect(find.textContaining('没有找到'), findsOneWidget);
    });
  });

  group('首页', () {
    testWidgets('加载收藏夹并只显示「儿童」开头的', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('动画'), findsOneWidget);
      expect(find.text('英语'), findsOneWidget);
      expect(find.text('默认收藏夹'), findsNothing);
      expect(find.textContaining('小猪佩奇 第一季'), findsOneWidget);
    });

    testWidgets('点击收藏夹标签过滤视频', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);

      await tester.tap(find.text('英语'));
      await settle(tester);
      expect(find.textContaining('Super Simple Songs'), findsOneWidget);
      expect(find.textContaining('小猪佩奇'), findsNothing);
    });

    testWidgets('下拉刷新拉到新建的收藏夹', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);
      expect(find.text('科普'), findsNothing);

      FakeBili.folders[13] = (
        title: '儿童科普',
        videos: [FakeBili.video('地球的奥秘', cover: 1)],
      );

      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, 300));
      await settle(tester);
      await settle(tester);

      expect(find.text('科普'), findsOneWidget, reason: '下拉刷新后应出现新收藏夹');
    });

    testWidgets('下拉刷新过程中能看到加载指示器', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      FakeBili.responseDelay = const Duration(milliseconds: 400);
      FakeBili.folders[13] = (
        title: '儿童科普',
        videos: [FakeBili.video('地球的奥秘', cover: 1)],
      );

      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CupertinoActivityIndicator), findsWidgets,
          reason: '刷新请求进行中应显示加载指示器');

      // 走完响应延迟 + 0.7s 最短可见时长 + 收起动画
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CupertinoActivityIndicator), findsNothing,
          reason: '刷新结束后指示器应收起');
      expect(find.text('科普'), findsOneWidget);
    });

    testWidgets('刷新后保持按 id 选中的收藏夹', (tester) async {
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);

      await tester.tap(find.text('英语'));
      await settle(tester);

      FakeBili.folders[13] = (
        title: '儿童科普',
        videos: [FakeBili.video('地球的奥秘', cover: 2)],
      );
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, 300));
      await settle(tester);
      await settle(tester);

      expect(find.textContaining('Super Simple Songs'), findsOneWidget);
      expect(find.textContaining('小猪佩奇'), findsNothing);
    });

    testWidgets('桌面平台显示点击刷新按钮，移动端不显示', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pumpApp(tester, MainShell(onLogout: () {}));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('引导式访问教程', () {
    testWidgets('三步翻页，每步有插图', (tester) async {
      await pumpApp(tester, const KidLockGuidePage(active: false));
      await tester.pumpAndSettle();

      expect(find.text('当前未开启引导式访问'), findsOneWidget);
      expect(find.text('第一步：开启引导式访问'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('第二步：在本 App 里启动'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('第三步：家长解除锁定'), findsOneWidget);
      expect(find.text('知道了'), findsOneWidget);
    });

    testWidgets('已在引导式访问中显示绿色状态', (tester) async {
      await pumpApp(tester, const KidLockGuidePage(active: true));
      await tester.pumpAndSettle();
      expect(find.text('当前已处于引导式访问中 ✓'), findsOneWidget);
    });
  });

  group('多尺寸无溢出', () {
    final sizes = {
      '小屏手机竖屏': phoneSmall,
      '手机横屏': phoneLandscape,
      'iPad 竖屏': ipadPortrait,
      'iPad 横屏': ipadLandscape,
    };
    for (final e in sizes.entries) {
      testWidgets('登录 FRE @ ${e.key}', (tester) async {
        await pumpApp(tester, LoginPage(onLoggedIn: () {}), size: e.value);
        await settle(tester);
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('首页 @ ${e.key}', (tester) async {
        await pumpApp(tester, MainShell(onLogout: () {}), size: e.value);
        await settle(tester);
      });
      testWidgets('引导式访问教程 @ ${e.key}', (tester) async {
        await pumpApp(tester, const KidLockGuidePage(active: false),
            size: e.value);
        await tester.pumpAndSettle();
      });
    }
  });
}
