import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:dlna_dart/xmlParser.dart' show PositionParser;
import 'package:flutter/cupertino.dart';

import '../api/bili_client.dart';
import '../models.dart';

/// 全局投屏会话：离开播放页后电视继续播，并轮询进度自动推下一集。
class CastSession extends ChangeNotifier {
  CastSession._();
  static final CastSession i = CastSession._();

  DLNADevice? _device;
  List<Episode> _episodes = const [];
  int _index = 0;
  Timer? _poller;
  bool _pushing = false;
  bool _sawNearEnd = false;

  bool get active => _device != null;
  String get deviceName => _device?.info.friendlyName ?? '';
  int get index => _index;

  Future<void> start(DLNADevice device, List<Episode> episodes, int index) async {
    _device = device;
    _episodes = episodes;
    try {
      await _push(index);
    } catch (_) {
      _device = null;
      rethrow;
    }
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
    notifyListeners();
  }

  Future<void> _push(int i) async {
    final ep = _episodes[i];
    final url = await BiliClient.i.castUrl(ep.bvid, ep.cid);
    await _device!.setUrl(url, title: ep.title);
    await _device!.play();
    _index = i;
    _sawNearEnd = false;
    notifyListeners();
  }

  /// 投屏中切集（选集/上一集/下一集都走这里）。
  Future<void> playIndex(int i) async {
    if (!active || _pushing || i < 0 || i >= _episodes.length) return;
    _pushing = true;
    try {
      await _push(i);
    } finally {
      _pushing = false;
    }
  }

  Future<void> _tick() async {
    final d = _device;
    if (d == null || _pushing) return;
    PositionParser p;
    try {
      p = PositionParser(await d.position());
    } catch (_) {
      // 有些电视播完直接结束会话，进度查询开始报错
      if (_sawNearEnd) await _advance();
      return;
    }
    final dur = p.TrackDurationInt;
    final rel = p.RelTimeInt;
    if (dur <= 0) return;
    if (dur - rel <= 3) {
      await _advance();
    } else if (dur - rel <= 20 && rel > 0) {
      _sawNearEnd = true;
    } else if (_sawNearEnd && rel <= 2) {
      // 快到片尾后进度回零：电视已播完并复位
      await _advance();
    }
  }

  Future<void> _advance() async {
    _sawNearEnd = false;
    if (_index + 1 >= _episodes.length) return;
    _pushing = true;
    try {
      await _push(_index + 1);
    } catch (_) {
      // 下一集推送失败（如网络抖动），下个轮询周期还有机会重试
    } finally {
      _pushing = false;
    }
  }

  Future<void> stop() async {
    _poller?.cancel();
    _poller = null;
    final d = _device;
    _device = null;
    notifyListeners();
    try {
      await d?.stop();
    } catch (_) {}
  }
}

/// 弹出投屏面板：搜索局域网 DLNA 设备，点选后投当前集并自动连播。
/// 投屏成功后回调 [onCasting]（用于暂停本地播放器）。
Future<void> showCastSheet(
  BuildContext context, {
  required List<Episode> episodes,
  required int index,
  required VoidCallback onCasting,
}) {
  return showCupertinoModalPopup(
    context: context,
    builder: (_) =>
        _CastSheet(episodes: episodes, index: index, onCasting: onCasting),
  );
}

class _CastSheet extends StatefulWidget {
  final List<Episode> episodes;
  final int index;
  final VoidCallback onCasting;
  const _CastSheet({
    required this.episodes,
    required this.index,
    required this.onCasting,
  });

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  final DLNAManager _manager = DLNAManager();
  List<DLNADevice> _devices = const [];
  StreamSubscription? _sub;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    CastSession.i.addListener(_onSession);
    _search();
  }

  void _onSession() {
    if (mounted) setState(() {});
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
    CastSession.i.removeListener(_onSession);
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
      await CastSession.i.start(device, widget.episodes, widget.index);
      widget.onCasting();
    } catch (e) {
      _error = '投屏失败：$e';
    }
    if (mounted) setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final casting = CastSession.i.active;
    return CupertinoActionSheet(
      title: casting
          ? Text('正在投屏到「${CastSession.i.deviceName}」\n播完一集会自动放下一集')
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
              : !casting && _devices.isEmpty
                  ? const Text('正在搜索局域网里的电视/投屏设备…\n请确认手机和电视连着同一个 Wi-Fi')
                  : null,
      actions: [
        if (casting)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => CastSession.i.stop(),
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
