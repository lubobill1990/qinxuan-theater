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

class _IntroStep {
  final IconData icon;
  final String title;
  final String body;
  const _IntroStep(this.icon, this.title, this.body);
}

const _intro = [
  _IntroStep(
    CupertinoIcons.play_rectangle_fill,
    '给孩子的专属小剧场',
    '亲选小剧场用你的哔哩哔哩账号登录，\n孩子只能看到你亲手挑选的视频。',
  ),
  _IntroStep(
    CupertinoIcons.folder_fill_badge_plus,
    '家长掌控内容',
    '在哔哩哔哩里创建以「儿童」开头的收藏夹，\n收藏进去的视频会自动出现在这里。\n\n随时增删收藏，随时更新内容。',
  ),
  _IntroStep(
    CupertinoIcons.checkmark_shield_fill,
    '专注不分心',
    '没有弹幕、评论和推荐，\n孩子不会被算法带走，看完就结束。\n\n还有儿童锁定，防止孩子离开 App。',
  ),
];

class _LoginPageState extends State<LoginPage> {
  final PageController _pc = PageController();
  int _page = 0;

  String? _qrUrl;
  String? _qrKey;
  String _status = '正在获取二维码…';
  bool _expired = false;
  Timer? _timer;

  int get _pageCount => _intro.length + 1;
  bool get _onQrPage => _page == _pageCount - 1;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
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

  void _goTo(int page) {
    _pc.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Widget _introPage(_IntroStep s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(s.icon, size: 52, color: CupertinoColors.activeBlue),
          ),
          const SizedBox(height: 32),
          Text(s.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text(s.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: CupertinoColors.secondaryLabel)),
        ],
      ),
    );
  }

  Widget _qrPage() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('亲选小剧场',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('登录哔哩哔哩账号',
                style: TextStyle(
                    fontSize: 17, color: CupertinoColors.secondaryLabel)),
            const SizedBox(height: 28),
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
                                  size: 48, color: CupertinoColors.activeBlue),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_status,
                style: const TextStyle(
                    fontSize: 15, color: CupertinoColors.secondaryLabel)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: _onQrPage
                  ? null
                  : Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        onPressed: () => _goTo(_pageCount - 1),
                        child:
                            const Text('跳过', style: TextStyle(fontSize: 15)),
                      ),
                    ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final s in _intro) _introPage(s),
                  _qrPage(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pageCount,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey3,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 20),
              child: ConstrainedBox(
                // iPad 上不让按钮拉满全宽
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: _onQrPage
                      ? null
                      : CupertinoButton.filled(
                          // 固定 48 高度下自带竖向 padding 会裁掉文字下半截
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () => _goTo(_page + 1),
                          child: Text(
                              _page == _intro.length - 1 ? '去扫码登录' : '下一步'),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
