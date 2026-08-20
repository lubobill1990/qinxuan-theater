import 'package:flutter/cupertino.dart';

class KidLockGuidePage extends StatefulWidget {
  final bool active;
  const KidLockGuidePage({super.key, required this.active});

  @override
  State<KidLockGuidePage> createState() => _KidLockGuidePageState();
}

class _Step {
  final String image;
  final String title;
  final String body;
  const _Step(this.image, this.title, this.body);
}

const _steps = [
  _Step(
    'assets/guide/ga_step1.png',
    '第一步：开启引导式访问',
    '引导式访问是 iPad / iPhone 自带的儿童锁定。\n\n'
        '打开 设置 → 辅助功能 → 引导式访问，\n打开开关并设置一个家长密码。',
  ),
  _Step(
    'assets/guide/ga_step2.png',
    '第二步：在本 App 里启动',
    '回到亲选小剧场，连按三下侧边（或顶部）按钮，\n再点屏幕右上角的「开始」。\n\n'
        '孩子就无法离开这个 App 了。',
  ),
  _Step(
    'assets/guide/ga_step3.png',
    '第三步：家长解除锁定',
    '想结束时，再连按三下侧边（或顶部）按钮，\n输入家长密码，点「结束」即可。',
  ),
];

class _KidLockGuidePageState extends State<KidLockGuidePage> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Widget _statusPill() {
    final active = widget.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? CupertinoColors.activeGreen.withOpacity(0.14)
            : CupertinoColors.tertiarySystemFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? '当前已处于引导式访问中 ✓' : '当前未开启引导式访问',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active
              ? CupertinoColors.activeGreen
              : CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _stepPage(_Step s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(s.image, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(s.title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
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

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _statusPill(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => _stepPage(_steps[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
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
                  child: CupertinoButton.filled(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: last
                        ? () => Navigator.of(context).pop()
                        : () => _pc.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut),
                    child: Text(last ? '知道了' : '下一步'),
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

void showKidLockGuide(BuildContext context, {required bool active}) {
  Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => KidLockGuidePage(active: active),
    ),
  );
}
