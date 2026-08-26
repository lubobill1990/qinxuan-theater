import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../app_settings.dart';
import '../kid_lock.dart';
import '../library.dart';
import '../models.dart';
import '../widgets/video_card.dart';
import 'guide_page.dart';
import 'player_page.dart';
import 'settings_page.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeTab({super.key, required this.onLogout});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  /// -1 表示「全部」
  int _selected = -1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  List<VideoItem> get _displayed {
    if (_selected == -1) return Library.i.all();
    final f = Library.i.folders[_selected];
    return Library.i.cache[f.id] ?? const [];
  }

  bool _refreshing = false;

  Future<void> _reload() async {
    if (_refreshing) return;
    setState(() {
      // 首次加载才整页转圈；下拉/点击刷新时保留旧列表
      _loading = Library.i.folders.isEmpty;
      _refreshing = true;
      _error = null;
    });
    final prevId = _selected >= 0 && _selected < Library.i.folders.length
        ? Library.i.folders[_selected].id
        : null;
    try {
      await Library.i.refresh();
      // 收藏夹可能新增/删除/换序，按 id 找回原选中项，找不到则回到「全部」
      _selected = prevId == null
          ? -1
          : Library.i.folders.indexWhere((f) => f.id == prevId);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadSelection() async {
    if (_selected == -1) {
      await Library.i.ensureAll();
    } else {
      await Library.i.videosOf(Library.i.folders[_selected]);
    }
  }

  Future<void> _selectFolder(int index) async {
    setState(() {
      _selected = index;
      _loading = true;
      _error = null;
    });
    try {
      await _loadSelection();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startTrial() async {
    await AppSettings.i.setTrialMode(true);
    Library.i.reset();
    _selected = -1;
    await _reload();
  }

  Future<void> _exitTrial() async {
    await AppSettings.i.setTrialMode(false);
    Library.i.reset();
    _selected = -1;
    await _reload();
  }

  Future<void> _showSettings() async {
    await KidLock.i.refresh();
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SettingsPage(onLogout: widget.onLogout),
      ),
    );
    // 设置里可能改了关键字或退出体验模式，回来刷新一次
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final folders = Library.i.folders;
    final videos = _displayed;
    final topInset = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      // 保证内容不足一屏、以及 Android 上也能触发下拉刷新
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // 必须是第一个 sliver，否则拿不到顶部 overscroll，既无动画也不触发刷新
        CupertinoSliverRefreshControl(
          // 接口快时转圈一闪而过，强制至少可见 0.7s
          onRefresh: () => Future.wait([
            _reload(),
            Future<void>.delayed(const Duration(milliseconds: 700)),
          ]),
          // 默认指示器画在刷新区顶部，而刷新区顶着屏幕上缘，
          // 会整个藏进刘海/状态栏，这里把它垫到安全区下方
          refreshTriggerPullDistance: 100 + topInset,
          refreshIndicatorExtent: 60 + topInset,
          builder: (ctx, state, pulled, trigger, extent) => Padding(
            padding: EdgeInsets.only(top: topInset),
            child: CupertinoSliverRefreshControl.buildRefreshIndicator(
                ctx, state, pulled, trigger, extent - topInset),
          ),
        ),
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
              child: Row(
                children: [
                  const Text('亲选小剧场',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_isDesktop)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _reload,
                      child: _refreshing
                          ? const CupertinoActivityIndicator(radius: 11)
                          : const Icon(CupertinoIcons.arrow_clockwise,
                              size: 24),
                    ),
                  if (_isDesktop) const SizedBox(width: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showSettings,
                    child: const Icon(CupertinoIcons.person_circle, size: 27),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (AppSettings.i.trialMode)
          SliverToBoxAdapter(child: _trialBanner()),
        if (folders.length > 1) SliverToBoxAdapter(child: _folderChips()),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else if (_error != null)
          SliverFillRemaining(hasScrollBody: false, child: _message(_error!))
        else if (folders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _message(
                      '没有找到「${AppSettings.i.kidKeywords.join('/')}」开头的收藏夹\n请先在哔哩哔哩里创建并收藏视频'),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => showGuide(context),
                    child: const Text('查看使用说明'),
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    onPressed: _startTrial,
                    child: const Text('先用预设内容快速体验'),
                  ),
                ],
              ),
            ),
          )
        else if (videos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _message('这里还没有视频'),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => showGuide(context),
                    child: const Text('查看使用说明'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomBarSpace),
            sliver: SliverGrid(
              gridDelegate: kVideoGridDelegate,
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => VideoCard(
                  video: videos[i],
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PlayerPage(bvid: videos[i].bvid),
                    ),
                  ),
                ),
                childCount: videos.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _trialBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.activeOrange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.sparkles,
                size: 18, color: CupertinoColors.activeOrange),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('正在体验预设内容',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _exitTrial,
              child: const Text('退出体验', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderChips() {
    final folders = Library.i.folders;
    String label(FavFolder f) {
      for (final k in AppSettings.i.kidKeywords) {
        if (f.title.startsWith(k)) {
          final t = f.title.substring(k.length).trim();
          return t.isEmpty ? f.title : t;
        }
      }
      return f.title;
    }

    Widget chip(String text, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? CupertinoColors.activeBlue
                : CupertinoColors.tertiarySystemFill,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: active ? CupertinoColors.white : CupertinoColors.label,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: folders.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => i == 0
              ? chip('全部', _selected == -1, () => _selectFolder(-1))
              : chip(label(folders[i - 1]), _selected == i - 1,
                  () => _selectFolder(i - 1)),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: CupertinoColors.secondaryLabel)),
      );
}
