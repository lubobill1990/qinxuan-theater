import 'package:flutter/cupertino.dart';

import '../api/bili_client.dart';
import '../app_settings.dart';
import '../kid_lock.dart';
import '../library.dart';
import '../screen_time.dart';
import 'guide_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsPage({super.key, required this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _openTimeLimit() async {
    if (!await KidLock.i.verifyParent(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const _TimeLimitPage()));
    if (mounted) setState(() {});
  }

  Future<void> _openKeywords() async {
    if (!await KidLock.i.verifyParent(context)) return;
    if (!mounted) return;
    await Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const _KeywordsPage()));
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await BiliClient.i.logout();
    await AppSettings.i.setTrialMode(false);
    Library.i.reset();
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.i;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
        previousPageTitle: '返回',
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('账号'),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.person_circle),
                  title: Text(BiliClient.i.uname),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('家长设置'),
              footer: const Text('修改以下设置需要家长密码'),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.timer),
                  title: const Text('观看时长限制'),
                  additionalInfo: Text(s.restAfterMin == 0 &&
                          s.dailyLimitMin == 0
                      ? '未开启'
                      : [
                          if (s.restAfterMin > 0) '连看 ${s.restAfterMin} 分钟休息',
                          if (s.dailyLimitMin > 0) '每日 ${s.dailyLimitMin} 分钟',
                        ].join('，')),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openTimeLimit,
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.tag),
                  title: const Text('收藏夹关键字'),
                  additionalInfo: Text(
                    s.kidKeywords.join('/'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openKeywords,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('儿童锁定'),
              children: [
                if (KidLock.i.supported)
                  ValueListenableBuilder<bool>(
                    valueListenable: KidLock.i.lockedN,
                    builder: (_, locked, __) => CupertinoListTile(
                      leading: const Icon(CupertinoIcons.lock),
                      title:
                          Text(locked ? '退出儿童锁定' : KidLock.i.enableLabel),
                      onTap: () async {
                        if (locked) {
                          await KidLock.i.disable(context);
                        } else {
                          await KidLock.i.enable(context);
                        }
                      },
                    ),
                  ),
                if (KidLock.i.iosGuide)
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.lock),
                    title: const Text('儿童锁定（引导式访问）'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => KidLock.i.showGuidedAccessHelp(context),
                  ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.book),
                  title: const Text('使用说明'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => showGuide(context),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('退出登录',
                      style:
                          TextStyle(color: CupertinoColors.destructiveRed)),
                  onTap: _logout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 观看时长限制 ----------

class _TimeLimitPage extends StatefulWidget {
  const _TimeLimitPage();

  @override
  State<_TimeLimitPage> createState() => _TimeLimitPageState();
}

class _TimeLimitPageState extends State<_TimeLimitPage> {
  static const _restAfterOptions = [0, 15, 20, 30, 45, 60];
  static const _restOptions = [5, 10, 15, 20, 30];
  static const _dailyOptions = [0, 30, 60, 90, 120, 180];

  String _label(int min) => min == 0 ? '关闭' : '$min 分钟';

  Future<void> _pick({
    required String title,
    required List<int> options,
    required int current,
    required Future<void> Function(int) onPick,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final v in options)
            CupertinoActionSheetAction(
              isDefaultAction: v == current,
              onPressed: () async {
                Navigator.pop(ctx);
                await onPick(v);
                if (mounted) setState(() {});
              },
              child: Text(v == current ? '${_label(v)} ✓' : _label(v)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _fmtToday(int sec) {
    final m = sec ~/ 60;
    if (m < 60) return '$m 分钟';
    return '${m ~/ 60} 小时 ${m % 60} 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.i;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('观看时长限制'),
        previousPageTitle: '设置',
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('今日'),
              children: [
                AnimatedBuilder(
                  animation: ScreenTime.i,
                  builder: (_, __) => CupertinoListTile(
                    leading: const Icon(CupertinoIcons.time),
                    title: const Text('今日已观看'),
                    additionalInfo: Text(_fmtToday(ScreenTime.i.todaySec)),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('连续观看'),
              footer: const Text('连续观看到设定时长后自动锁定休息，'
                  '休息倒计时结束自动恢复，家长可输入密码提前解锁'),
              children: [
                CupertinoListTile(
                  title: const Text('连看多久必须休息'),
                  additionalInfo: Text(_label(s.restAfterMin)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pick(
                    title: '连看多久必须休息',
                    options: _restAfterOptions,
                    current: s.restAfterMin,
                    onPick: s.setRestAfterMin,
                  ),
                ),
                CupertinoListTile(
                  title: const Text('每次休息时长'),
                  additionalInfo: Text(_label(s.restMin)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pick(
                    title: '每次休息时长',
                    options: _restOptions,
                    current: s.restMin,
                    onPick: s.setRestMin,
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('每日上限'),
              footer: const Text('当日观看总时长到达上限后锁定，'
                  '家长输入密码解锁后当天不再限制'),
              children: [
                CupertinoListTile(
                  title: const Text('每日观看上限'),
                  additionalInfo: Text(_label(s.dailyLimitMin)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pick(
                    title: '每日观看上限',
                    options: _dailyOptions,
                    current: s.dailyLimitMin,
                    onPick: s.setDailyLimitMin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 收藏夹关键字 ----------

class _KeywordsPage extends StatefulWidget {
  const _KeywordsPage();

  @override
  State<_KeywordsPage> createState() => _KeywordsPageState();
}

class _KeywordsPageState extends State<_KeywordsPage> {
  Future<void> _add() async {
    final ctrl = TextEditingController();
    final v = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('添加关键字'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            placeholder: '例如：亲选',
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    final list = List<String>.from(AppSettings.i.kidKeywords);
    if (list.contains(v)) return;
    list.add(v);
    await AppSettings.i.setKidKeywords(list);
    if (mounted) setState(() {});
  }

  Future<void> _remove(String k) async {
    final list = List<String>.from(AppSettings.i.kidKeywords)..remove(k);
    await AppSettings.i.setKidKeywords(list);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final keywords = AppSettings.i.kidKeywords;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('收藏夹关键字'),
        previousPageTitle: '设置',
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('关键字'),
              footer: const Text('哔哩哔哩里名字以任一关键字开头的收藏夹会显示在首页。'
                  '至少保留一个关键字，修改后下拉刷新首页生效。'),
              children: [
                for (final k in keywords)
                  CupertinoListTile(
                    title: Text(k),
                    trailing: keywords.length > 1
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _remove(k),
                            child: const Icon(
                                CupertinoIcons.minus_circle_fill,
                                color: CupertinoColors.destructiveRed,
                                size: 22),
                          )
                        : null,
                  ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.add_circled,
                      color: CupertinoColors.activeBlue),
                  title: const Text('添加关键字',
                      style: TextStyle(color: CupertinoColors.activeBlue)),
                  onTap: _add,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
