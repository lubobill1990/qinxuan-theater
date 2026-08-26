import 'package:flutter/cupertino.dart';

import '../screen_time.dart';

/// 观看时长到点的全屏锁定页：休息锁显示倒计时（结束自动解锁），
/// 每日锁只能家长解锁。页面不可返回，pop 只由 ScreenTime 发起。
class LockPage extends StatelessWidget {
  const LockPage({super.key});

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFF1C1C2E),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: ScreenTime.i,
            builder: (context, _) {
              final st = ScreenTime.i;
              final daily = st.lock == LockKind.daily;
              return SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Color(0x22FFD60A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.moon_zzz_fill,
                          size: 60, color: Color(0xFFFFD60A)),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      daily ? '今天看够啦' : '休息一下',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      daily
                          ? '今天的观看时间已经用完\n去玩点别的吧，明天再来看'
                          : '看了好一会儿了\n让眼睛休息休息再继续吧',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xB3FFFFFF)),
                    ),
                    if (!daily) ...[
                      const SizedBox(height: 28),
                      Text(
                        _fmt(st.restRemainSec),
                        style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                            fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(height: 4),
                      const Text('倒计时结束自动继续',
                          style: TextStyle(
                              fontSize: 13, color: Color(0x80FFFFFF))),
                    ],
                    const SizedBox(height: 48),
                    CupertinoButton(
                      onPressed: () => st.parentUnlock(context),
                      child: const Text('家长解锁',
                          style: TextStyle(
                              fontSize: 15, color: Color(0x99FFFFFF))),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
