import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/bili_client.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginPage({super.key, required this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _qrUrl;
  String? _qrKey;
  String _status = '正在获取二维码…';
  bool _expired = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    _timer?.cancel();
    setState(() {
      _qrUrl = null;
      _expired = false;
      _status = '正在获取二维码…';
    });
    try {
      final qr = await BiliClient.i.qrGenerate();
      if (!mounted) return;
      setState(() {
        _qrUrl = qr.url;
        _qrKey = qr.key;
        _status = '请用哔哩哔哩 App 扫码登录';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      if (mounted) setState(() => _status = '获取二维码失败，点击重试');
      _expired = true;
    }
  }

  Future<void> _poll() async {
    if (_qrKey == null) return;
    try {
      final code = await BiliClient.i.qrPoll(_qrKey!);
      if (!mounted) return;
      switch (code) {
        case 0:
          _timer?.cancel();
          await BiliClient.i.checkLogin();
          widget.onLoggedIn();
        case 86090:
          setState(() => _status = '已扫码，请在手机上确认');
        case 86038:
          _timer?.cancel();
          setState(() {
            _expired = true;
            _status = '二维码已过期，点击刷新';
          });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('亲选小剧场',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('登录哔哩哔哩账号',
                style: TextStyle(
                    fontSize: 17, color: CupertinoColors.secondaryLabel)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _expired ? _refresh : null,
              child: Container(
                width: 240,
                height: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: _qrUrl == null
                    ? const Center(child: CupertinoActivityIndicator())
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          QrImageView(data: _qrUrl!, padding: EdgeInsets.zero),
                          if (_expired)
                            Container(
                              color: const Color(0xCCFFFFFF),
                              alignment: Alignment.center,
                              child: const Icon(CupertinoIcons.refresh,
                                  size: 48,
                                  color: CupertinoColors.activeBlue),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(_status,
                style: const TextStyle(
                    fontSize: 15, color: CupertinoColors.secondaryLabel)),
          ],
        ),
      ),
    );
  }
}
