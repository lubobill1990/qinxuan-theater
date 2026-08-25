import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:dlna_dart/xmlParser.dart' show PositionParser;
import 'package:flutter/cupertino.dart';

import '../api/bili_client.dart';
import '../models.dart';
import '../screen_awake.dart';
import '../watch_history.dart';

/// 全局投屏会话：离开播放页后电视继续播，并轮询进度自动推下一集。
class CastSession extends ChangeNotifier {
  CastSession._();
  static final CastSession i = CastSession._();

  DLNADevice? _device;
  List<Episode> _episodes = const [];
  int _index = 0;
  Timer? _poller;
  int _pollCount = 0;
  bool _pushing = false;
  bool _sawNearEnd = false;
  int _lastRel = 0;
  int _zeroTicks = 0;

  /// 电视端播放进度/时长（秒），由轮询刷新
  int posSec = 0;
  int durSec = 0;
  bool paused = false;

  /// 直链清晰度：16=360P 32=480P 64=720P 80=1080P
  int qn = 80;

  /// 正在投的合集元信息（写观看历史、悬浮入口跳转用）
  String castKey = '';
  String castTitle = '';
  String castCover = '';

  /// stop() 前的进度快照，供播放页回落本地续播
  int lastSessionPosSec = 0;

  bool get active => _device != null;
  String get deviceName => _device?.info.friendlyName ?? '';
  int get index => _index;
  List<Episode> get episodes => _episodes;
  Episode? get currentEpisode =>
      active && _index < _episodes.length ? _episodes[_index] : null;

  Future<void> start(
    DLNADevice device,
    List<Episode> episodes,
    int index, {
    required String key,
    required String title,
    required String cover,
    int startSec = 0,
  }) async {
    final old = _device;
    final oldEpisodes = _episodes;
    final oldKey = castKey, oldTitle = castTitle, oldCover = castCover;
    if (old == null) ScreenAwake.acquire();
    _poller?.cancel();
    _device = device;
    _episodes = episodes;
    castKey = key;
    castTitle = title;
    castCover = cover;
    try {
      await _push(index);
    } catch (_) {
      _device = old;
      _episodes = oldEpisodes;
      castKey = oldKey;
      castTitle = oldTitle;
      castCover = oldCover;
      if (old == null) {
        ScreenAwake.release();
      } else {
        _startPoller();
      }
      rethrow;
    }
    await _seekWhenReady(startSec);
    if (old != null && !identical(old, device)) {
      try {
        await old.stop();
      } catch (_) {}
    }
    _startPoller();
    notifyListeners();
  }

  void _startPoller() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 1), (_) => _pollTick());
  }

  /// 每秒本地推算进度让 UI 平滑走秒，每 4 秒向电视校准一次
  void _pollTick() {
    if (_device == null) return;
    if (++_pollCount % 4 == 0) {
      _tick();
    } else if (!paused && !_pushing && durSec > 0 && posSec < durSec) {
      posSec++;
      notifyListeners();
    }
  }

  /// 新内容推送后把电视 seek 到指定位置并确认生效。
  /// 太早 seek 会打在还没卸载的旧片源上或被直接吞掉，所以先等
  /// TrackURI 换成新直链再 seek；seek 后还要验证进度真的跳了过去，
  /// 验证成功前不改 _lastRel，避免「进度归零=播完」误判触发连播重推。
  Future<void> _seekWhenReady(int sec) async {
    final d = _device;
    if (d == null || sec <= 5) return;
    posSec = sec; // 乐观显示目标进度，随后校准
    notifyListeners();
    var loaded = false;
    var attempts = 0;
    var seekAt = -10;
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!identical(d, _device)) return;
      PositionParser p;
      try {
        p = PositionParser(await d.position());
      } catch (_) {
        continue;
      }
      final dur = p.TrackDurationInt;
      final rel = p.RelTimeInt;
      if (!loaded) loaded = p.TrackURI == _lastUrl || rel <= 5;
      if (!loaded || dur <= 0) continue;
      if (rel >= 5 && rel >= sec - 15) {
        durSec = dur;
        posSec = rel;
        _lastRel = rel;
        _zeroTicks = 0;
        _sawNearEnd = dur - rel <= 20;
        notifyListeners();
        return;
      }
      if (attempts < 3 && i - seekAt >= 3) {
        attempts++;
        seekAt = i;
        try {
          await d.seek(_hms(sec));
        } catch (_) {}
      }
    }
    // 电视始终不认这个 seek，接受从头播，把本地状态校准回真实进度
    try {
      final p = PositionParser(await d.position());
      posSec = p.RelTimeInt;
    } catch (_) {
      posSec = 0;
    }
    _lastRel = posSec;
    notifyListeners();
  }

  /// 投屏中换一个视频：同设备重推新内容。
  Future<void> castContent(
    List<Episode> eps,
    int index, {
    required String key,
    required String title,
    required String cover,
    int startSec = 0,
  }) async {
    if (!active || _pushing) return;
    _pushing = true;
    _episodes = eps;
    castKey = key;
    castTitle = title;
    castCover = cover;
    try {
      await _push(index);
      await _seekWhenReady(startSec);
    } finally {
      _pushing = false;
    }
  }

  String _lastUrl = '';

  Future<void> _push(int i) async {
    final ep = _episodes[i];
    final url = await BiliClient.i.castUrl(ep.bvid, ep.cid, qn: qn);
    await _device!.setUrl(url, title: ep.title);
    await _device!.play();
    _lastUrl = url;
    _index = i;
    _sawNearEnd = false;
    _lastRel = 0;
    _zeroTicks = 0;
    posSec = 0;
    durSec = 0;
    paused = false;
    notifyListeners();
  }

  /// 该集在观看历史里的进度（秒），看完的集记 0 自然从头播
  int _savedSecFor(int i) {
    final ep = _episodes[i];
    return (WatchHistory.i.find(castKey)?.posFor(ep.bvid, ep.cid) ?? 0) ~/
        1000;
  }

  /// 投屏中切集（选集/上一集/下一集都走这里），按该集历史进度续播。
  Future<void> playIndex(int i) async {
    if (!active || _pushing || i < 0 || i >= _episodes.length) return;
    if (i == _index) return;
    _pushing = true;
    try {
      await _push(i);
      await _seekWhenReady(_savedSecFor(i));
    } finally {
      _pushing = false;
    }
  }

  Future<void> pause() async {
    final d = _device;
    if (d == null) return;
    paused = true;
    notifyListeners();
    try {
      await d.pause();
    } catch (_) {
      paused = false;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    final d = _device;
    if (d == null) return;
    paused = false;
    notifyListeners();
    try {
      await d.play();
    } catch (_) {}
  }

  static String _hms(int s) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  Future<void> seekTo(int sec) async {
    final d = _device;
    if (d == null) return;
    if (durSec > 0) sec = sec.clamp(0, durSec);
    if (sec < 0) sec = 0;
    posSec = sec;
    _lastRel = sec;
    _zeroTicks = 0;
    _sawNearEnd = durSec > 0 && durSec - sec <= 20;
    notifyListeners();
    try {
      await d.seek(_hms(sec));
    } catch (_) {}
  }

  Future<void> seekBy(int delta) => seekTo(posSec + delta);

  /// 切清晰度：重推当前集并跳回原进度。
  Future<void> setQuality(int newQn) async {
    if (!active || _pushing || newQn == qn) return;
    qn = newQn;
    final pos = posSec;
    _pushing = true;
    try {
      await _push(_index);
      await _seekWhenReady(pos);
    } finally {
      _pushing = false;
    }
  }

  /// 换投屏设备：新设备接着当前进度播，旧设备停。
  Future<void> switchDevice(DLNADevice d) async {
    final old = _device;
    if (old == null || _pushing) return;
    final pos = posSec;
    _pushing = true;
    _device = d;
    try {
      await _push(_index);
      await _seekWhenReady(pos);
    } catch (_) {
      _device = old;
      notifyListeners();
      rethrow;
    } finally {
      _pushing = false;
    }
    try {
      await old.stop();
    } catch (_) {}
  }

  /// 调电视音量（DLNA RenderingControl，先查再设）。
  Future<void> changeTvVolume(int delta) async {
    final d = _device;
    if (d == null) return;
    try {
      await d.changeVolume(delta);
    } catch (_) {}
  }

  Future<void> _tick() async {
    final d = _device;
    if (d == null || _pushing) return;
    ScreenAwake.refresh();
    PositionParser p;
    try {
      p = PositionParser(await d.position());
    } catch (_) {
      // 有些电视播完直接结束会话，进度查询开始报错
      if (_sawNearEnd && !paused) await _advance();
      return;
    }
    final dur = p.TrackDurationInt;
    final rel = p.RelTimeInt;
    if (dur <= 0) {
      // app 被挂起期间电视播完并回到待机：曾播到 30s 以上、
      // 现在连时长都查不到，连续两个周期即视为播完，补推下一集
      if (!paused && _lastRel > 30 && ++_zeroTicks >= 2) await _advance();
      return;
    }
    durSec = dur;
    posSec = rel;
    if (rel > _lastRel) {
      // 电视遥控器直接恢复了播放
      if (paused) paused = false;
      _lastRel = rel;
      _zeroTicks = 0;
    }
    notifyListeners();
    _recordHistory();
    if (paused) return;
    if (dur - rel <= 3) {
      await _advance();
    } else if (dur - rel <= 20 && rel > 0) {
      _sawNearEnd = true;
    } else if (_sawNearEnd && rel <= 2) {
      // 快到片尾后进度回零：电视已播完并复位
      await _advance();
    } else if (rel == 0 && _lastRel > 30) {
      // 解锁回来发现进度归零（电视已播完重置），连续两个周期确认后补推
      if (++_zeroTicks >= 2) await _advance();
    }
  }

  Future<void> _advance() async {
    _sawNearEnd = false;
    if (_index + 1 >= _episodes.length) return;
    final next = _index + 1;
    _pushing = true;
    try {
      await _push(next);
      await _seekWhenReady(_savedSecFor(next));
    } catch (_) {
      // 下一集推送失败（如网络抖动），下个轮询周期还有机会重试
    } finally {
      _pushing = false;
    }
  }

  void _recordHistory() {
    if (castKey.isEmpty || durSec <= 0 || posSec < 3) return;
    final ep = currentEpisode;
    if (ep == null) return;
    final nearEnd = durSec - posSec < 10 && posSec > durSec * 0.9;
    WatchHistory.i.record(HistoryEntry(
      key: castKey,
      title: castTitle,
      cover: castCover.isNotEmpty ? castCover : ep.cover,
      epBvid: ep.bvid,
      cid: ep.cid,
      epTitle: ep.title,
      positionMs: nearEnd ? 0 : posSec * 1000,
      durationMs: durSec * 1000,
    ));
  }

  Future<void> stop() async {
    _poller?.cancel();
    _poller = null;
    lastSessionPosSec = posSec;
    final d = _device;
    if (d != null) ScreenAwake.release();
    _device = null;
    posSec = 0;
    durSec = 0;
    paused = false;
    notifyListeners();
    try {
      await d?.stop();
    } catch (_) {}
  }
}

/// 弹出投屏面板：搜索局域网 DLNA 设备，点选后投当前集并自动连播。
/// 投屏中再次打开可换设备或停止投屏。
/// 投屏成功后回调 [onCasting]（用于暂停本地播放器）。
Future<void> showCastSheet(
  BuildContext context, {
  required List<Episode> episodes,
  required int index,
  required String castKey,
  required String title,
  required String cover,
  int startSec = 0,
  required VoidCallback onCasting,
}) {
  return showCupertinoModalPopup(
    context: context,
    builder: (_) => _CastSheet(
      episodes: episodes,
      index: index,
      castKey: castKey,
      title: title,
      cover: cover,
      startSec: startSec,
      onCasting: onCasting,
    ),
  );
}

class _CastSheet extends StatefulWidget {
  final List<Episode> episodes;
  final int index;
  final String castKey;
  final String title;
  final String cover;
  final int startSec;
  final VoidCallback onCasting;
  const _CastSheet({
    required this.episodes,
    required this.index,
    required this.castKey,
    required this.title,
    required this.cover,
    required this.startSec,
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
      // reusePort：B 站等 app 投屏时会占住 SSDP 的 1900 端口，必须共享绑定
      final dm = await _manager.start(reusePort: true);
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
      if (CastSession.i.active && CastSession.i.castKey == widget.castKey) {
        await CastSession.i.switchDevice(device);
      } else {
        // 未投屏，或投屏中打开了另一个视频：直接投新内容（旧设备会被停掉）
        await CastSession.i.start(
          device,
          widget.episodes,
          widget.index,
          key: widget.castKey,
          title: widget.title,
          cover: widget.cover,
          startSec: widget.startSec,
        );
        widget.onCasting();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _error = '投屏失败：$e';
    }
    if (mounted) setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final casting = CastSession.i.active;
    final others = casting
        ? _devices
            .where((d) => d.info.friendlyName != CastSession.i.deviceName)
            .toList()
        : _devices;
    return CupertinoActionSheet(
      title: casting
          ? Text('正在投屏到「${CastSession.i.deviceName}」')
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
              : casting
                  ? (others.isEmpty
                      ? const Text('正在搜索其他可投屏的设备…')
                      : const Text('点其他设备可直接换过去接着播'))
                  : _devices.isEmpty
                      ? const Text('正在搜索局域网里的电视/投屏设备…\n请确认手机和电视连着同一个 Wi-Fi')
                      : null,
      actions: [
        for (final d in others)
          CupertinoActionSheetAction(
            onPressed: _connecting ? () {} : () => _cast(d),
            child: Text(casting ? '换到「${d.info.friendlyName}」' : d.info.friendlyName),
          ),
        if (casting)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              CastSession.i.stop();
              Navigator.pop(context);
            },
            child: const Text('停止投屏'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
    );
  }
}
