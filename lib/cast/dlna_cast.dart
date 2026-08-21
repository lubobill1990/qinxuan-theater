import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/cupertino.dart';

/// 弹出投屏面板：搜索局域网 DLNA 设备，点选后推送直链播放。
/// [getUrl] 在用户选中设备时才调用（拿当前集的投屏直链）。
/// 投屏成功后回调 [onCasting]（用于暂停本地播放器）。
Future<void> showCastSheet(
  BuildContext context, {
  required Future<String> Function() getUrl,
  required String title,
  required VoidCallback onCasting,
}) {
  return showCupertinoModalPopup(
    context: context,
    builder: (_) => _CastSheet(getUrl: getUrl, title: title, onCasting: onCasting),
  );
}

class _CastSheet extends StatefulWidget {
  final Future<String> Function() getUrl;
  final String title;
  final VoidCallback onCasting;
  const _CastSheet({
    required this.getUrl,
    required this.title,
    required this.onCasting,
  });

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  final DLNAManager _manager = DLNAManager();
  List<DLNADevice> _devices = const [];
  StreamSubscription? _sub;

  /// null=未投；投中显示设备名
  DLNADevice? _casting;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    try {
      final dm = await _manager.start();
      // devices 是单订阅流，每次打开面板都新建 DeviceManager，不能复用
      _sub = dm.devices.stream.listen((map) {
        if (mounted) setState(() => _devices = map.values.toList());
      });
    } catch (e) {
      if (mounted) setState(() => _error = '搜索设备失败：$e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _manager.stop();
    super.dispose();
  }

  Future<void> _cast(DLNADevice device) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final url = await widget.getUrl();
      await device.setUrl(url, title: widget.title);
      await device.play();
      widget.onCasting();
      if (mounted) {
        setState(() {
          _casting = device;
          _connecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '投屏失败：$e';
        });
      }
    }
  }

  Future<void> _stopCast() async {
    final d = _casting;
    setState(() => _casting = null);
    try {
      await d?.stop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final casting = _casting;
    return CupertinoActionSheet(
      title: casting != null
          ? Text('正在投屏到「${casting.info.friendlyName}」')
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('选择投屏设备'),
                SizedBox(width: 8),
                CupertinoActivityIndicator(radius: 8),
              ],
            ),
      message: _error != null
          ? Text(_error!)
          : _connecting
              ? const Text('正在连接…')
              : casting == null && _devices.isEmpty
                  ? const Text('正在搜索局域网里的电视/投屏设备…\n请确认手机和电视连着同一个 Wi-Fi')
                  : null,
      actions: [
        if (casting != null)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: _stopCast,
            child: const Text('停止投屏'),
          )
        else
          for (final d in _devices)
            CupertinoActionSheetAction(
              onPressed: _connecting ? () {} : () => _cast(d),
              child: Text(d.info.friendlyName),
            ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
    );
  }
}
