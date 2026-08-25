import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import 'dlna_cast.dart';

/// 投屏中替代本地播放器显示的控制面板：
/// 进度条拖动定位、播放/暂停、±10s、上/下一集、清晰度、换设备、退出投屏。
/// 手机上按硬件音量键调的是电视音量。
class CastControlPanel extends StatefulWidget {
  final VoidCallback onShowDevices;
  const CastControlPanel({super.key, required this.onShowDevices});

  @override
  State<CastControlPanel> createState() => _CastControlPanelState();
}

class _CastControlPanelState extends State<CastControlPanel> {
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

  Widget _ctrl(IconData icon,
      {required double size, VoidCallback? onTap, bool enabled = true}) {
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      onPressed: enabled ? onTap : null,
      child: Icon(icon,
          size: size,
          color: enabled ? CupertinoColors.white : const Color(0x55FFFFFF)),
    );
  }

  Widget _textAction(String label, VoidCallback onTap, {Color? color}) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onPressed: onTap,
      child: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xCCFFFFFF))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
        return Container(
          color: const Color(0xFF1C1C1E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.cast_connected,
                  size: 40, color: CupertinoColors.activeBlue),
              const SizedBox(height: 10),
              Text('正在投屏到「${s.deviceName}」',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0x99FFFFFF))),
              const SizedBox(height: 4),
              Text(
                s.currentEpisode?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white),
              ),
              if (_note != null) ...[
                const SizedBox(height: 6),
                Text(_note!,
                    style: const TextStyle(
                        fontSize: 13, color: CupertinoColors.activeBlue)),
              ],
              const Spacer(),
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(_mmss(pos),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0x99FFFFFF))),
                  ),
                  Expanded(
                    child: CupertinoSlider(
                      value: canSeek
                          ? pos.clamp(0, dur).toDouble()
                          : 0,
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
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(_mmss(dur),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0x99FFFFFF))),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ctrl(Icons.skip_previous,
                      size: 32,
                      enabled: s.index > 0,
                      onTap: () => s.playIndex(s.index - 1)),
                  _ctrl(CupertinoIcons.gobackward_10,
                      size: 26, enabled: canSeek, onTap: () => s.seekBy(-10)),
                  _ctrl(
                    s.paused
                        ? CupertinoIcons.play_circle_fill
                        : CupertinoIcons.pause_circle_fill,
                    size: 54,
                    onTap: () => s.paused ? s.resume() : s.pause(),
                  ),
                  _ctrl(CupertinoIcons.goforward_10,
                      size: 26, enabled: canSeek, onTap: () => s.seekBy(10)),
                  _ctrl(Icons.skip_next,
                      size: 32,
                      enabled: s.index + 1 < s.episodes.length,
                      onTap: () => s.playIndex(s.index + 1)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _textAction(qLabel, () => _pickQuality(context)),
                  _textAction('音量 −', () {
                    CastSession.i.changeTvVolume(-5);
                    _showNote('电视音量 −');
                  }),
                  _textAction('音量 +', () {
                    CastSession.i.changeTvVolume(5);
                    _showNote('电视音量 +');
                  }),
                  _textAction('换设备', widget.onShowDevices),
                  _textAction('退出投屏', () => s.stop(),
                      color: CupertinoColors.systemRed),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
