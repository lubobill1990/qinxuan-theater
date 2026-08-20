import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../api/bili_client.dart';
import '../watch_history.dart';

class PlayerPage extends StatefulWidget {
  final String bvid;
  const PlayerPage({super.key, required this.bvid});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  ViewInfo? _info;
  int _current = 0;
  String? _error;
  Timer? _ticker;
  StreamSubscription<bool>? _completedSub;

  @override
  void initState() {
    super.initState();
    _completedSub = _player.stream.completed.listen((done) {
      if (done) _autoNext();
    });
    _setup();
  }

  bool _advancing = false;

  Future<void> _autoNext() async {
    final info = _info;
    if (!mounted || info == null || _advancing) return;
    if (_current + 1 >= info.episodes.length) return;
    _advancing = true;
    try {
      await _play(_current + 1);
    } finally {
      _advancing = false;
    }
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    _ticker?.cancel();
    _record();
    _player.dispose();
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      if (_player.platform is NativePlayer) {
        final np = _player.platform as NativePlayer;
        await np.setProperty('referrer', 'https://www.bilibili.com/');
        await np.setProperty('user-agent', kUserAgent);
      }
      final info = await BiliClient.i.viewInfo(widget.bvid);

      await WatchHistory.i.load();
      var startIndex = info.initialIndex;
      var startPos = Duration.zero;
      final h = WatchHistory.i.find(widget.bvid);
      if (h != null) {
        final idx = info.episodes
            .indexWhere((e) => e.bvid == h.epBvid && e.cid == h.cid);
        if (idx >= 0) {
          startIndex = idx;
          startPos = Duration(milliseconds: h.positionMs);
        }
      }

      if (!mounted) return;
      setState(() {
        _info = info;
        _current = startIndex;
      });
      await _play(startIndex, resumeFrom: startPos);
      _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _record());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _play(int index, {Duration resumeFrom = Duration.zero}) async {
    final ep = _info!.episodes[index];
    setState(() => _current = index);
    try {
      final src = await BiliClient.i.playUrl(ep.bvid, ep.cid);
      final resume = resumeFrom > const Duration(seconds: 5);
      await _player.open(Media(
        src.videoUrl,
        httpHeaders: {
          'Referer': 'https://www.bilibili.com/',
          'User-Agent': kUserAgent,
        },
        start: resume ? resumeFrom : null,
      ));
      if (src.audioUrl != null) {
        await _player.setAudioTrack(AudioTrack.uri(src.audioUrl!));
      }
      if (resume) {
        // start 参数偶尔不生效时的兜底
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted || _current != index) return;
          final diff = _player.state.position - resumeFrom;
          if (diff.abs() > const Duration(seconds: 5)) {
            await _player.seek(resumeFrom);
          }
        });
      }
      _record();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _record() {
    final info = _info;
    if (info == null) {
      debugPrint('[history] skip: info null');
      return;
    }
    final pos = _player.state.position;
    final dur = _player.state.duration;
    debugPrint('[history][$hashCode] tick pos=$pos dur=$dur');
    if (dur == Duration.zero || pos < const Duration(seconds: 3)) return;
    final ep = info.episodes[_current];
    final nearEnd = dur - pos < const Duration(seconds: 10) &&
        pos.inMilliseconds > dur.inMilliseconds * 0.9;
    WatchHistory.i.record(HistoryEntry(
      key: widget.bvid,
      title: info.title,
      cover: info.cover.isNotEmpty ? info.cover : ep.cover,
      epBvid: ep.bvid,
      cid: ep.cid,
      epTitle: ep.title,
      positionMs: nearEnd ? 0 : pos.inMilliseconds,
      durationMs: dur.inMilliseconds,
    ));
  }

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  bool _immersive = false;

  Widget _video(ViewInfo info) {
    final hasPrev = _current > 0;
    final hasNext = _current + 1 < info.episodes.length;
    // 控制条可能持有旧的按钮列表，回调里必须重新校验边界
    void prev() {
      if (_current > 0) _play(_current - 1);
    }

    void next() {
      if (_current + 1 < info.episodes.length) _play(_current + 1);
    }

    if (_isMobile) {
      final theme = MaterialVideoControlsThemeData(
        primaryButtonBar: [
          const Spacer(flex: 2),
          if (hasPrev)
            MaterialCustomButton(
                onPressed: prev,
                icon: const Icon(Icons.skip_previous),
                iconSize: 36),
          const Spacer(),
          const MaterialPlayOrPauseButton(iconSize: 48),
          const Spacer(),
          if (hasNext)
            MaterialCustomButton(
                onPressed: next,
                icon: const Icon(Icons.skip_next),
                iconSize: 36),
          const Spacer(flex: 2),
        ],
      );
      return MaterialVideoControlsTheme(
        normal: theme,
        fullscreen: theme,
        child: Video(controller: _controller, controls: MaterialVideoControls),
      );
    }
    final theme = MaterialDesktopVideoControlsThemeData(
      bottomButtonBar: [
        if (hasPrev)
          MaterialDesktopCustomButton(
              onPressed: prev, icon: const Icon(Icons.skip_previous)),
        const MaterialDesktopPlayOrPauseButton(),
        if (hasNext)
          MaterialDesktopCustomButton(
              onPressed: next, icon: const Icon(Icons.skip_next)),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        const MaterialDesktopFullscreenButton(),
      ],
    );
    return MaterialDesktopVideoControlsTheme(
      normal: theme,
      fullscreen: theme,
      child: Video(
          controller: _controller, controls: MaterialDesktopVideoControls),
    );
  }

  void _setImmersive(bool on) {
    if (_immersive == on) return;
    _immersive = on;
    SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // 手机/iPad 横屏：视频自动全屏
    if (_isMobile && landscape && info != null && _error == null) {
      _setImmersive(true);
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFF000000),
        child: Stack(
          children: [
            Positioned.fill(child: _video(info)),
            Positioned(
              top: 6,
              left: 6,
              child: SafeArea(
                child: CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.chevron_back,
                        size: 22, color: CupertinoColors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    _setImmersive(false);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          info == null
              ? ''
              : (info.episodes.length > 1
                  ? info.episodes[_current].title
                  : info.title),
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: '返回',
      ),
      child: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('播放出错了\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel)),
                ),
              )
            : info == null
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : LayoutBuilder(builder: (ctx, constraints) {
                    final wide = constraints.maxWidth > constraints.maxHeight;
                    final video = ColoredBox(
                      color: const Color(0xFF000000),
                      child: _video(info),
                    );
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(child: video),
                          if (info.episodes.length > 1)
                            SizedBox(width: 340, child: _episodeList(info)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        AspectRatio(aspectRatio: 16 / 9, child: video),
                        if (info.episodes.length > 1)
                          Expanded(child: _episodeList(info))
                        else
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(info.title,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    );
                  }),
      ),
    );
  }

  Widget _episodeList(ViewInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text('选集（${info.episodes.length}）',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: info.episodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final ep = info.episodes[i];
              final active = i == _current;
              return GestureDetector(
                onTap: () => _play(i),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active
                        ? CupertinoColors.activeBlue.withOpacity(0.12)
                        : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: active
                        ? Border.all(
                            color: CupertinoColors.activeBlue, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 112,
                          height: 63,
                          child: CachedNetworkImage(
                            imageUrl: ep.cover,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const ColoredBox(
                                color: CupertinoColors.tertiarySystemFill),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ep.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.label,
                          ),
                        ),
                      ),
                      if (active)
                        const Padding(
                          padding: EdgeInsets.only(left: 8, right: 4),
                          child: Icon(CupertinoIcons.play_fill,
                              size: 18, color: CupertinoColors.activeBlue),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
