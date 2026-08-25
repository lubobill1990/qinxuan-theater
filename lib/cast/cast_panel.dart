import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import 'dlna_cast.dart';

/// 投屏中替代播放页显示的整页控制屏（仿 B 站投屏页）：
/// 进度条拖动定位、播放/暂停、±10s、上/下一集、选集、清晰度、换设备、退出投屏。
/// 手机上按硬件音量键调的是电视音量。
class CastPage extends StatefulWidget {
  final VoidCallback onShowDevices;
  const CastPage({super.key, required this.onShowDevices});

  @override
  State<CastPage> createState() => _CastPageState();
}

class _CastPageState extends State<CastPage> {
  static const _qualities = [
    (80, '1080P'),
    (64, '720P'),
    (32, '480P'),
    (16, '360P'),
  ];

  /// 音量键侦测基线：本机音量钉在 0.5，偏离即视为一次按键
  static const _base = 0.5;

  bool _dragging = false;
  double _dragValue = 0;
  double? _origVolume;
  bool _restoringVolume = false;
  String? _note;
  Timer? _noteTimer;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_isMobile) _hookVolumeKeys();
  }

  Future<void> _hookVolumeKeys() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      _origVolume = await FlutterVolumeController.getVolume();
      await FlutterVolumeController.setVolume(_base);
      FlutterVolumeController.addListener(_onVolumeKey);
    } catch (_) {}
  }

  void _onVolumeKey(double v) {
    if (_restoringVolume || (v - _base).abs() < 0.01) return;
    final up = v > _base;
    CastSession.i.changeTvVolume(up ? 5 : -5);
    _showNote(up ? '电视音量 +' : '电视音量 −');
    _restoringVolume = true;
    FlutterVolumeController.setVolume(_base)
        .whenComplete(() => _restoringVolume = false);
  }

  void _showNote(String text) {
    _noteTimer?.cancel();
    setState(() => _note = text);
    _noteTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _note = null);
    });
  }

  @override
  void dispose() {
    _noteTimer?.cancel();
    if (_isMobile) {
      FlutterVolumeController.removeListener();
      final orig = _origVolume;
      if (orig != null) FlutterVolumeController.setVolume(orig);
      FlutterVolumeController.updateShowSystemUI(true);
    }
    super.dispose();
  }

  String _mmss(int s) {
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _pickQuality(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('清晰度'),
        actions: [
          for (final (qn, label) in _qualities)
            CupertinoActionSheetAction(
              isDefaultAction: qn == CastSession.i.qn,
              onPressed: () {
                Navigator.pop(ctx);
                CastSession.i.setQuality(qn);
              },
              child: Text(qn == CastSession.i.qn ? '$label ✓' : label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _pickEpisode(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: CastSession.i,
            builder: (_, __) {
              final s = CastSession.i;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Text('选集（${s.episodes.length}）',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: s.episodes.length,
                      itemBuilder: (_, i) {
                        final ep = s.episodes[i];
                        final active = i == s.index;
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          onPressed: () {
                            Navigator.pop(ctx);
                            s.playIndex(i);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ep.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: active
                                        ? CupertinoColors.activeBlue
                                        : CupertinoColors.white,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(CupertinoIcons.play_fill,
                                    size: 16,
                                    color: CupertinoColors.activeBlue),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pill({required Widget child, VoidCallback? onTap}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      ),
    );
  }

  Widget _segItem(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 12),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 13, color: Color(0x99FFFFFF))),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white)),
          ],
        ),
      ),
    );
  }

  Widget _ctrl(IconData icon,
      {required double size, VoidCallback? onTap, bool enabled = true}) {
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      onPressed: enabled ? onTap : null,
      child: Icon(icon,
          size: size,
          color: enabled ? CupertinoColors.white : const Color(0x55FFFFFF)),
    );
  }

  Widget _bottomAction(String label, VoidCallback? onTap) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onPressed: onTap,
      child: Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: onTap == null
                  ? const Color(0x55FFFFFF)
                  : CupertinoColors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF141417),
      child: AnimatedBuilder(
        animation: CastSession.i,
        builder: (context, _) {
          final s = CastSession.i;
          if (!s.active) return const SizedBox.shrink();
          final dur = s.durSec;
          final pos = _dragging ? _dragValue.round() : s.posSec;
          final canSeek = dur > 0;
          final qLabel = _qualities
              .firstWhere((q) => q.$1 == s.qn, orElse: () => _qualities.first)
              .$2;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Icon(CupertinoIcons.chevron_back,
                            size: 26, color: CupertinoColors.white),
                      ),
                      Expanded(
                        child: Text(
                          s.currentEpisode?.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: () => s.stop(),
                        child: const Icon(Icons.power_settings_new,
                            size: 24, color: CupertinoColors.white),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  const Text('正在投屏到',
                      style:
                          TextStyle(fontSize: 13, color: Color(0x99FFFFFF))),
                  const SizedBox(height: 8),
                  Text(
                    s.deviceName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white),
                  ),
                  const SizedBox(height: 18),
                  _pill(
                    onTap: widget.onShowDevices,
                    child: const Text('换设备',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white)),
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    height: 20,
                    child: _note == null
                        ? null
                        : Text(_note!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.activeBlue)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF232326),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _segItem('清晰度', qLabel, () => _pickQuality(context)),
                        Container(
                            width: 0.5,
                            height: 30,
                            color: const Color(0x33FFFFFF)),
                        _segItem('音量', '−', () {
                          s.changeTvVolume(-5);
                          _showNote('电视音量 −');
                        }),
                        Container(
                            width: 0.5,
                            height: 30,
                            color: const Color(0x33FFFFFF)),
                        _segItem('音量', '+', () {
                          s.changeTvVolume(5);
                          _showNote('电视音量 +');
                        }),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ctrl(CupertinoIcons.gobackward_10,
                          size: 30,
                          enabled: canSeek,
                          onTap: () => s.seekBy(-10)),
                      const SizedBox(width: 26),
                      _ctrl(
                        s.paused
                            ? CupertinoIcons.play_circle_fill
                            : CupertinoIcons.pause_circle_fill,
                        size: 72,
                        onTap: () => s.paused ? s.resume() : s.pause(),
                      ),
                      const SizedBox(width: 26),
                      _ctrl(CupertinoIcons.goforward_10,
                          size: 30, enabled: canSeek, onTap: () => s.seekBy(10)),
                    ],
                  ),
                  const Spacer(flex: 3),
                  CupertinoSlider(
                    value: canSeek ? pos.clamp(0, dur).toDouble() : 0,
                    max: canSeek ? dur.toDouble() : 1,
                    onChangeStart: canSeek
                        ? (v) => setState(() {
                              _dragging = true;
                              _dragValue = v;
                            })
                        : null,
                    onChanged: canSeek
                        ? (v) => setState(() => _dragValue = v)
                        : null,
                    onChangeEnd: canSeek
                        ? (v) {
                            setState(() => _dragging = false);
                            s.seekTo(v.round());
                          }
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_mmss(pos),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0x99FFFFFF))),
                        Text(_mmss(dur),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0x99FFFFFF))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _bottomAction(
                          '选集',
                          s.episodes.length > 1
                              ? () => _pickEpisode(context)
                              : null),
                      const Spacer(),
                      _bottomAction(
                          '上一集',
                          s.index > 0
                              ? () => s.playIndex(s.index - 1)
                              : null),
                      _bottomAction(
                          '下一集',
                          s.index + 1 < s.episodes.length
                              ? () => s.playIndex(s.index + 1)
                              : null),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
