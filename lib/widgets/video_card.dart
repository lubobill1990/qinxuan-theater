import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../models.dart';

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  const VideoCard({super.key, required this.video, required this.onTap});

  String get _duration {
    final h = video.duration ~/ 3600;
    final m = (video.duration % 3600) ~/ 60;
    final s = (video.duration % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                        color: CupertinoColors.tertiarySystemFill),
                    errorWidget: (_, __, ___) => const ColoredBox(
                        color: CupertinoColors.tertiarySystemFill,
                        child: Icon(CupertinoIcons.play_rectangle, size: 40)),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_duration,
                          style: const TextStyle(
                              fontSize: 12, color: CupertinoColors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              // 固定两行高度，避免单行标题的卡片封面比别人高
              child: SizedBox(
                height: 42,
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double kBottomBarSpace = 110;

const kVideoGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 320,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  childAspectRatio: 16 / 12.5,
);
