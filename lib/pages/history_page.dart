import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../watch_history.dart';
import '../widgets/video_card.dart';
import 'player_page.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  void initState() {
    super.initState();
    WatchHistory.i.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _confirmClear() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有浏览历史吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              WatchHistory.i.clear();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: WatchHistory.i.version,
      builder: (ctx, _, __) {
        final entries = WatchHistory.i.entries;
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 4),
                child: Row(
                  children: [
                    const Text('历史',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (entries.isNotEmpty)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _confirmClear,
                        child: const Text('清空',
                            style: TextStyle(fontSize: 15)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text('还没有看过视频',
                            style: TextStyle(
                                fontSize: 16,
                                color: CupertinoColors.secondaryLabel)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            16, 8, 16, kBottomBarSpace),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _HistoryRow(
                          entry: entries[i],
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) =>
                                  PlayerPage(bvid: entries[i].key),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  const _HistoryRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = entry.positionMs == 0
        ? '已看完'
        : '看到 ${fmtMs(entry.positionMs)} / ${fmtMs(entry.durationMs)}';
    final ratio = entry.durationMs <= 0
        ? 0.0
        : entry.positionMs == 0
            ? 1.0
            : (entry.positionMs / entry.durationMs).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 112,
                height: 63,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: entry.cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                          color: CupertinoColors.tertiarySystemFill),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 3,
                        color: const Color(0x66000000),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          heightFactor: 1,
                          child: const ColoredBox(
                              color: CupertinoColors.activeBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (entry.epTitle != entry.title)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(entry.epTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.secondaryLabel)),
                    ),
                  const SizedBox(height: 4),
                  Text('$progress · ${relativeDay(entry.updatedAt)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel)),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: CupertinoColors.tertiaryLabel),
          ],
        ),
      ),
    );
  }
}
