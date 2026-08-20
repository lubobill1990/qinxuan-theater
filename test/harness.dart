import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bilibili_kid_viewer/library.dart';

import 'fake_http.dart';

bool _fontsLoaded = false;

/// 加载图标字体和系统中文字体，否则截图里全是方块。
Future<void> loadTestFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  final manifest = await rootBundle.loadString('FontManifest.json');
  for (final entry in jsonDecode(manifest) as List) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  final candidates = [
    r'C:\Windows\Fonts\msyh.ttc',
    '/System/Library/Fonts/PingFang.ttc',
  ];
  final path = candidates.firstWhere((p) => File(p).existsSync(),
      orElse: () => '');
  if (path.isEmpty) return;
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.view(bytes.buffer);
  // Cupertino/Material 默认字体族在测试环境不存在，把中文字体注册到这些族名上
  for (final family in [
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    'Roboto',
  ]) {
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  }
}

/// 每个用例前重置全局状态并接管网络。
Future<void> setUpTestEnv({Map<String, Object> prefs = const {}}) async {
  HttpOverrides.global = FakeBiliHttpOverrides();
  FakeBili.reset();
  Library.i.reset();
  SharedPreferences.setMockInitialValues({
    'guide_shown': true,
    ...prefs,
  });
  await loadTestFonts();
}

/// 截图测试额外环境：让 cached_network_image（path_provider + sqflite）真正工作，
/// 从而在 golden 里渲染出真实封面图。
Future<void> setUpScreenshotEnv() async {
  await setUpTestEnv();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  final tmp = Directory.systemTemp.createTempSync('kidviewer_test_cache');
  addTearDown(() {
    // cache_manager 的 sqlite 连接可能仍占用文件，删不掉就留给系统临时目录
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => tmp.path,
  );
}

/// 真实异步（网络、磁盘、图片解码）推进 + 渲染帧，供截图测试用。
Future<void> realSettle(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 60));
  }
  // 让 CachedNetworkImage 的淡入动画播完，避免截图截到半透明状态
  await tester.pump(const Duration(seconds: 1));
}

/// 结束截图测试：卸载组件并把 cache_manager 遗留的清理 Timer 跑完。
Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump(const Duration(minutes: 1));
}

const phonePortrait = Size(390, 844);
const phoneLandscape = Size(844, 390);
const phoneSmall = Size(320, 568);
const ipadPortrait = Size(1024, 1366);
const ipadLandscape = Size(1366, 1024);

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Size size = phonePortrait,
  double keyboardInset = 0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      theme: const CupertinoThemeData(brightness: Brightness.light),
      home: keyboardInset > 0
          ? Builder(
              builder: (ctx) => MediaQuery(
                data: MediaQuery.of(ctx)
                    .copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
                child: child,
              ),
            )
          : child,
    ),
  );
}

/// 等待网络 future / 图片解码等异步完成。
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
