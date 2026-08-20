import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'api/bili_client.dart';
import 'kid_lock.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'win_title_bar.dart';

final navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await KidLock.i.init(navKey);
  if (Platform.isWindows) {
    const opts = WindowOptions(titleBarStyle: TitleBarStyle.hidden);
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const KidViewerApp());
}

class KidViewerApp extends StatelessWidget {
  const KidViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '亲选小剧场',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      builder: (ctx, child) {
        if (!Platform.isWindows) return child!;
        return Column(
          children: [
            const WinTitleBar(),
            Expanded(child: child!),
          ],
        );
      },
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      theme: const CupertinoThemeData(brightness: Brightness.light),
      home: const Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await BiliClient.i.init();
    var ok = false;
    try {
      ok = await BiliClient.i.checkLogin();
    } catch (_) {}
    if (mounted) setState(() => _loggedIn = ok);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_loggedIn) {
      null => const CupertinoPageScaffold(
          child: Center(child: CupertinoActivityIndicator(radius: 14))),
      false => LoginPage(onLoggedIn: () => setState(() => _loggedIn = true)),
      true => MainShell(onLogout: () => setState(() => _loggedIn = false)),
    };
  }
}
