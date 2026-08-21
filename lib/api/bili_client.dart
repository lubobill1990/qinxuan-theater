import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

const kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

class PlaySource {
  final String videoUrl;
  final String? audioUrl;
  PlaySource(this.videoUrl, this.audioUrl);
}

class ViewInfo {
  final String title;
  final String cover;
  final List<Episode> episodes;
  final int initialIndex;
  ViewInfo({
    required this.title,
    required this.cover,
    required this.episodes,
    required this.initialIndex,
  });
}

class BiliClient {
  BiliClient._();
  static final BiliClient i = BiliClient._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': kUserAgent,
      'Referer': 'https://www.bilibili.com/',
    },
  ));

  final Map<String, String> _cookies = {};
  String? _mixinKey;
  int mid = 0;
  String uname = '';

  bool get hasSession => _cookies.containsKey('SESSDATA');

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cookies');
    if (raw != null) {
      (jsonDecode(raw) as Map<String, dynamic>)
          .forEach((k, v) => _cookies[k] = v as String);
    }
    if (!_cookies.containsKey('buvid3')) {
      try {
        final r = await _get('https://api.bilibili.com/x/frontend/finger/spi');
        _cookies['buvid3'] = r['b_3'] as String;
        _cookies['buvid4'] = r['b_4'] as String;
        await _persistCookies();
      } catch (_) {}
    }
  }

  Future<void> _persistCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', jsonEncode(_cookies));
  }

  Future<void> logout() async {
    _cookies.removeWhere((k, _) => k != 'buvid3' && k != 'buvid4');
    mid = 0;
    uname = '';
    await _persistCookies();
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<dynamic> _get(String url,
      {Map<String, dynamic>? params, bool sign = false}) async {
    var p = params ?? <String, dynamic>{};
    if (sign) p = _wbiSign(p);
    final resp = await _dio.get(url,
        queryParameters: p,
        options: Options(headers: {'Cookie': _cookieHeader}));
    final body = resp.data is String ? jsonDecode(resp.data) : resp.data;
    if (body['code'] != 0) {
      throw Exception('B站接口错误 ${body['code']}: ${body['message']}');
    }
    return body['data'];
  }

  void _absorbSetCookies(Headers headers) {
    for (final line in headers['set-cookie'] ?? const <String>[]) {
      final pair = line.split(';').first;
      final eq = pair.indexOf('=');
      if (eq > 0) {
        _cookies[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
      }
    }
  }

  // ---------- WBI 签名 ----------

  static const _mixinTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, //
    49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55,
    40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57,
    62, 11, 36, 20, 34, 44, 52
  ];

  Map<String, dynamic> _wbiSign(Map<String, dynamic> params) {
    final key = _mixinKey;
    if (key == null) return params;
    final p = Map<String, dynamic>.from(params);
    p['wts'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final keys = p.keys.toList()..sort();
    final query = keys.map((k) {
      final v = p[k].toString().replaceAll(RegExp(r"[!'()*]"), '');
      return '${Uri.encodeComponent(k)}=${Uri.encodeComponent(v)}';
    }).join('&');
    p['w_rid'] = md5.convert(utf8.encode(query + key)).toString();
    return p;
  }

  String _keyFromUrl(String url) {
    final name = url.split('/').last;
    return name.split('.').first;
  }

  // ---------- 登录 ----------

  /// 返回 true 表示已登录，并顺带取得 WBI 密钥与用户信息。
  Future<bool> checkLogin() async {
    final resp = await _dio.get('https://api.bilibili.com/x/web-interface/nav',
        options: Options(headers: {'Cookie': _cookieHeader}));
    final body = resp.data is String ? jsonDecode(resp.data) : resp.data;
    final data = body['data'];
    final wbi = data?['wbi_img'];
    if (wbi != null) {
      _mixinKey = _mixinTab
          .map((idx) => (_keyFromUrl(wbi['img_url'] as String) +
              _keyFromUrl(wbi['sub_url'] as String))[idx])
          .join();
    }
    if (data?['isLogin'] == true) {
      mid = data['mid'] as int;
      uname = data['uname'] as String;
      return true;
    }
    return false;
  }

  Future<({String url, String key})> qrGenerate() async {
    final d = await _get(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/generate');
    return (url: d['url'] as String, key: d['qrcode_key'] as String);
  }

  /// 返回 poll code：0 成功、86101 未扫码、86090 已扫码待确认、86038 已过期
  Future<int> qrPoll(String key) async {
    final resp = await _dio.get(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
        queryParameters: {'qrcode_key': key},
        options: Options(headers: {'Cookie': _cookieHeader}));
    final body = resp.data is String ? jsonDecode(resp.data) : resp.data;
    final code = body['data']['code'] as int;
    if (code == 0) {
      _absorbSetCookies(resp.headers);
      await _persistCookies();
    }
    return code;
  }

  // ---------- 收藏夹 ----------

  Future<List<FavFolder>> kidFavFolders() async {
    final d = await _get(
        'https://api.bilibili.com/x/v3/fav/folder/created/list-all',
        params: {'up_mid': mid});
    final list = (d?['list'] ?? []) as List;
    return list
        .map((j) => FavFolder.fromJson(j as Map<String, dynamic>))
        .where((f) => f.title.startsWith('儿童'))
        .toList();
  }

  Future<List<VideoItem>> favVideos(int mediaId) async {
    final items = <VideoItem>[];
    for (var pn = 1; pn <= 5; pn++) {
      final d = await _get('https://api.bilibili.com/x/v3/fav/resource/list',
          params: {'media_id': mediaId, 'pn': pn, 'ps': 40, 'platform': 'web'});
      final medias = (d?['medias'] ?? []) as List;
      items.addAll(medias
          .cast<Map<String, dynamic>>()
          .where((j) => j['attr'] == 0 && j['type'] == 2)
          .map(VideoItem.fromFavJson));
      if (d?['has_more'] != true) break;
    }
    return items;
  }

  // ---------- 视频详情 / 系列 ----------

  Future<ViewInfo> viewInfo(String bvid) async {
    final d = await _get('https://api.bilibili.com/x/web-interface/view',
        params: {'bvid': bvid});
    final title = d['title'] as String;
    final cover = d['pic'] as String;
    final episodes = <Episode>[];
    var initial = 0;

    final season = d['ugc_season'];
    if (season != null) {
      for (final sec in (season['sections'] as List)) {
        for (final ep in (sec['episodes'] as List)) {
          episodes.add(Episode(
            bvid: ep['bvid'] as String,
            cid: ep['cid'] as int,
            title: ep['title'] as String,
            cover: (ep['arc']?['pic'] ?? '') as String,
          ));
        }
      }
      initial = episodes.indexWhere((e) => e.bvid == bvid);
      if (initial < 0) initial = 0;
    } else {
      final pages = (d['pages'] ?? []) as List;
      if (pages.length > 1) {
        for (final p in pages) {
          episodes.add(Episode(
            bvid: bvid,
            cid: p['cid'] as int,
            title: p['part'] as String,
            cover: cover,
          ));
        }
      } else {
        episodes.add(
            Episode(bvid: bvid, cid: d['cid'] as int, title: title, cover: cover));
      }
    }
    return ViewInfo(
        title: title, cover: cover, episodes: episodes, initialIndex: initial);
  }

  Future<PlaySource> playUrl(String bvid, int cid) async {
    final d = await _get('https://api.bilibili.com/x/player/wbi/playurl',
        params: {
          'bvid': bvid,
          'cid': cid,
          'qn': 80,
          'fnval': 16,
          'fnver': 0,
          'fourk': 1,
        },
        sign: true);
    final dash = d['dash'];
    if (dash != null) {
      final videos = (dash['video'] as List).cast<Map<String, dynamic>>();
      final avc = videos.where((v) => v['codecid'] == 7).toList();
      final pick = (avc.isNotEmpty ? avc : videos).first;
      final audios = ((dash['audio'] ?? []) as List).cast<Map<String, dynamic>>();
      return PlaySource(
        pick['baseUrl'] as String,
        audios.isNotEmpty ? audios.first['baseUrl'] as String : null,
      );
    }
    final durl = (d['durl'] as List).first;
    return PlaySource(durl['url'] as String, null);
  }

  /// 投屏用直链：html5 平台返回单文件 mp4（durl），
  /// 电视不会带 Referer，这种直链没有防盗链限制才能播。
  Future<String> castUrl(String bvid, int cid) async {
    final d = await _get('https://api.bilibili.com/x/player/wbi/playurl',
        params: {
          'bvid': bvid,
          'cid': cid,
          'qn': 80,
          'fnval': 1,
          'fnver': 0,
          'platform': 'html5',
          'high_quality': 1,
        },
        sign: true);
    final durl = (d['durl'] as List).first;
    return durl['url'] as String;
  }
}
