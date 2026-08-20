import 'package:flutter/cupertino.dart';

import '../api/bili_client.dart';
import '../kid_lock.dart';
import '../library.dart';
import '../models.dart';
import '../widgets/video_card.dart';
import 'guide_page.dart';
import 'player_page.dart';

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

  List<VideoItem> get _displayed {
    if (_selected == -1) return Library.i.all();
    final f = Library.i.folders[_selected];
    return Library.i.cache[f.id] ?? const [];
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    Library.i.reset();
    try {
      await Library.i.loadFolders(force: true);
      if (_selected >= Library.i.folders.length) _selected = -1;
      await _loadSelection();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
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

  void _showSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(BiliClient.i.uname),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showGuide(context);
            },
            child: const Text('使用说明'),
          ),
          if (KidLock.i.supported)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(ctx);
                if (KidLock.i.locked) {
                  await KidLock.i.disable(context);
                } else {
                  await KidLock.i.enable(context);
                }
                if (mounted) setState(() {});
              },
              child: Text(KidLock.i.locked ? '退出儿童锁定' : '进入儿童锁定（全屏，退出需家长密码）'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await BiliClient.i.logout();
              Library.i.reset();
              widget.onLogout();
            },
            child: const Text('退出登录'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = Library.i.folders;
    final videos = _displayed;
    return CustomScrollView(
      slivers: [
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
        CupertinoSliverRefreshControl(onRefresh: _reload),
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
                  _message('没有找到「儿童」开头的收藏夹\n请先在哔哩哔哩里创建并收藏视频'),
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
        else if (videos.isEmpty)
          SliverFillRemaining(
              hasScrollBody: false, child: _message('这里还没有视频'))
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

  Widget _folderChips() {
    final folders = Library.i.folders;
    String label(FavFolder f) {
      final t = f.title.replaceFirst('儿童', '').trim();
      return t.isEmpty ? f.title : t;
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
