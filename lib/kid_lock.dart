import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/kid_lock_guide_page.dart';

class KidLock with WindowListener {
  KidLock._();
  static final KidLock i = KidLock._();

  static const MethodChannel _ch = MethodChannel('kid_lock');

  final ValueNotifier<bool> lockedN = ValueNotifier(false);
  bool get locked => lockedN.value;
  GlobalKey<NavigatorState>? _navKey;

  bool get supported => Platform.isWindows || Platform.isAndroid;
  bool get iosGuide => Platform.isIOS;

  String get enableLabel => Platform.isWindows
      ? '进入儿童锁定（全屏，退出需家长密码）'
      : '进入儿童锁定（固定屏幕，退出需家长密码）';

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navKey = navKey;
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
  }

  /// Android 上系统手势也能解锁，打开设置前同步一次真实状态
  Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    try {
      lockedN.value = await _ch.invokeMethod<bool>('isLocked') ?? false;
    } catch (_) {}
  }

  Future<String?> _storedPin() async =>
      (await SharedPreferences.getInstance()).getString('kid_pin');

  Future<bool> enable(BuildContext context) async {
    if (!supported) return false;
    var pin = await _storedPin();
    if (pin == null) {
      if (!context.mounted) return false;
      final v = await _promptPin(context, '设置家长密码', '首次使用请设置密码（至少 4 位数字）');
      if (v == null || v.length < 4) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kid_pin', v);
    }
    if (Platform.isWindows) {
      await windowManager.setFullScreen(true);
      await windowManager.setPreventClose(true);
    } else if (Platform.isAndroid) {
      final ok = await _ch.invokeMethod<bool>('startLockTask') ?? false;
      if (!ok) return false;
    }
    lockedN.value = true;
    return true;
  }

  Future<bool> disable(BuildContext context) async {
    final pin = await _storedPin();
    if (!context.mounted) return false;
    final v = await _promptPin(context, '输入家长密码', null);
    if (v == null || v != pin) return false;
    if (Platform.isWindows) {
      await windowManager.setFullScreen(false);
      await windowManager.setPreventClose(false);
    } else if (Platform.isAndroid) {
      await _ch.invokeMethod('stopLockTask');
    }
    lockedN.value = false;
    return true;
  }

  Future<void> showGuidedAccessHelp(BuildContext context) async {
    bool active = false;
    try {
      active = await _ch.invokeMethod<bool>('isGuidedAccess') ?? false;
    } catch (_) {}
    if (!context.mounted) return;
    showKidLockGuide(context, active: active);
  }

  @override
  void onWindowClose() async {
    final ctx = _navKey?.currentContext;
    if (!locked || ctx == null) return;
    if (await disable(ctx)) {
      await windowManager.close();
    }
  }

  Future<String?> _promptPin(
      BuildContext context, String title, String? hint) {
    final ctrl = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(hint),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                autofocus: true,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
