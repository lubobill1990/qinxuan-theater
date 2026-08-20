import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

import 'kid_lock.dart';

class WinTitleBar extends StatelessWidget {
  const WinTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KidLock.i.lockedN,
      builder: (ctx, locked, _) {
        if (locked) return const SizedBox.shrink();
        return Container(
          height: 34,
          color: CupertinoColors.systemGroupedBackground,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                  child: DragToMoveArea(
                    child: Row(
                      children: const [
                        SizedBox(width: 14),
                        Icon(CupertinoIcons.play_rectangle_fill,
                            size: 15, color: CupertinoColors.activeBlue),
                        SizedBox(width: 7),
                        Text('亲选小剧场',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.secondaryLabel)),
                      ],
                    ),
                  ),
                ),
              ),
              _CaptionButton(
                icon: CupertinoIcons.minus,
                onTap: () => windowManager.minimize(),
              ),
              _CaptionButton(
                icon: CupertinoIcons.square,
                iconSize: 12,
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
              _CaptionButton(
                icon: CupertinoIcons.xmark,
                hoverColor: const Color(0xFFE81123),
                hoverIconColor: CupertinoColors.white,
                onTap: () => windowManager.close(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color hoverColor;
  final Color hoverIconColor;
  final VoidCallback onTap;
  const _CaptionButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 14,
    this.hoverColor = const Color(0x14000000),
    this.hoverIconColor = CupertinoColors.label,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: double.infinity,
          color: _hover ? widget.hoverColor : const Color(0x00000000),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _hover ? widget.hoverIconColor : CupertinoColors.label,
          ),
        ),
      ),
    );
  }
}
