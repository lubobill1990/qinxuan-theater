import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class KidLock with WindowListener {
  KidLock._();
  static final KidLock i = KidLock._();

  final ValueNotifier<bool> lockedN = ValueNotifier(false);
  bool get locked => lockedN.value;
  GlobalKey<NavigatorState>? _navKey;

  bool get supported => Platform.isWindows;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navKey = navKey;
    if (!supported) return;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
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
    lockedN.value = true;
    await windowManager.setFullScreen(true);
    await windowManager.setPreventClose(true);
    return true;
  }

  Future<bool> disable(BuildContext context) async {
    final pin = await _storedPin();
    if (!context.mounted) return false;
    final v = await _promptPin(context, '输入家长密码', null);
    if (v == null || v != pin) return false;
    lockedN.value = false;
    await windowManager.setFullScreen(false);
    await windowManager.setPreventClose(false);
    return true;
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
