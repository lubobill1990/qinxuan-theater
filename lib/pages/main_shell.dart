import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../cast/dlna_cast.dart';
import '../library.dart';
import '../models.dart';
import '../widgets/video_card.dart';
import 'guide_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'player_page.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    guideShown().then((shown) {
      if (!shown && mounted) showGuide(context);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _query = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          Positioned.fill(
            child: _searchActive
                ? _SearchView(query: _query)
                : IndexedStack(
                    index: _tab,
                    children: [
                      HomeTab(onLogout: widget.onLogout),
                      const HistoryTab(),
                    ],
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            // 键盘高度由 CupertinoPageScaffold 的 resizeToAvoidBottomInset
            // 自动补偿，这里不要再叠加 viewInsets，否则会双倍上移
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _castingBar(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                          child: child,
                        ),
                      ),
                      child:
                          _searchActive ? _expandedSearch() : _collapsedBar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 投屏中 mini player 条：悬浮在 tab 栏上方，点击进投屏控制页
  Widget _castingBar() {
    return AnimatedBuilder(
      animation: CastSession.i,
      builder: (context, _) {
        final s = CastSession.i;
        if (!s.active) return const SizedBox.shrink();
        final ep = s.currentEpisode;
        final cover = s.castCover.isNotEmpty ? s.castCover : (ep?.cover ?? '');
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => PlayerPage(bvid: s.castKey)),
            ),
            child: _glass(
              radius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 36,
                        child: cover.isEmpty
                            ? const ColoredBox(
                                color: CupertinoColors.tertiarySystemFill)
                            : CachedNetworkImage(
                                imageUrl: cover,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const ColoredBox(
                                    color:
                                        CupertinoColors.tertiarySystemFill),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cast_connected,
                                  size: 12, color: CupertinoColors.activeBlue),
                              SizedBox(width: 4),
                              Text('投屏中',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.activeBlue)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ep?.title ?? s.castTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () => s.paused ? s.resume() : s.pause(),
                      child: Icon(
                        s.paused
                            ? CupertinoIcons.play_fill
                            : CupertinoIcons.pause_fill,
                        size: 22,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glass({required BorderRadius radius, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
              color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xBFF8F8FA),
              borderRadius: radius,
              border: Border.all(color: const Color(0x59FFFFFF), width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _collapsedBar() {
    return Row(
      key: const ValueKey('tabs'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _glass(
          radius: BorderRadius.circular(32),
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TabItem(
                  icon: CupertinoIcons.house_fill,
                  label: '主页',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _TabItem(
                  icon: CupertinoIcons.clock_fill,
                  label: '历史',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => setState(() => _searchActive = true),
          child: _glass(
            radius: BorderRadius.circular(31),
            child: const SizedBox(
              width: 62,
              height: 62,
              child: Icon(CupertinoIcons.search,
                  size: 24, color: CupertinoColors.label),
            ),
          ),
        ),
      ],
    );
  }

  Widget _expandedSearch() {
    return Row(
      key: const ValueKey('search'),
      children: [
        Expanded(
          child: _glass(
            radius: BorderRadius.circular(28),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  child: CupertinoSearchTextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    placeholder: '搜索视频',
                    style: const TextStyle(fontSize: 16),
                    decoration:
                        const BoxDecoration(color: Color(0x00000000)),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.only(left: 14, right: 2),
          onPressed: _closeSearch,
          child: const Text('取消', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? CupertinoColors.activeBlue : CupertinoColors.secondaryLabel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SearchView extends StatefulWidget {
  final String query;
  const _SearchView({required this.query});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  List<VideoItem>? _all;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Library.i.ensureAll();
      if (mounted) setState(() => _all = Library.i.all());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(
                  fontSize: 15, color: CupertinoColors.secondaryLabel)));
    }
    if (_all == null) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) {
      return const Center(
          child: Text('输入关键词搜索视频',
              style: TextStyle(
                  fontSize: 16, color: CupertinoColors.secondaryLabel)));
    }
    final results =
        _all!.where((v) => v.title.toLowerCase().contains(q)).toList();
    if (results.isEmpty) {
      return Center(
          child: Text('没有找到「${widget.query.trim()}」相关的视频',
              style: const TextStyle(
                  fontSize: 16, color: CupertinoColors.secondaryLabel)));
    }
    return SafeArea(
      bottom: false,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomBarSpace),
        gridDelegate: kVideoGridDelegate,
        itemCount: results.length,
        itemBuilder: (ctx, i) => VideoCard(
          video: results[i],
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => PlayerPage(bvid: results[i].bvid),
            ),
          ),
        ),
      ),
    );
  }
}
