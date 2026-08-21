import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 可在测试中随时增删的收藏夹数据源。
class FakeBili {
  static final Map<int, ({String title, List<Map<String, dynamic>> videos})>
      folders = {};

  static int _vid = 0;

  /// 模拟慢网络，让测试能观察到「请求进行中」的 UI 状态。
  static Duration responseDelay = Duration.zero;

  static Map<String, dynamic> video(String title, {int cover = 1}) => {
        'bvid': 'BV${(++_vid).toString().padLeft(8, '0')}',
        'title': title,
        'cover': 'https://i0.hdslb.com/fake/cover${(cover - 1) % 6 + 1}.png',
        'duration': 245,
        'attr': 0,
        'type': 2,
        'upper': {'name': '测试UP主'},
      };

  static void reset() {
    _vid = 0;
    responseDelay = Duration.zero;
    folders
      ..clear()
      ..addAll({
        11: (
          title: '儿童动画',
          videos: [
            video('小猪佩奇 第一季 合集', cover: 1),
            video('超级飞侠 乐迪的环球旅行', cover: 2),
            video('汪汪队立大功 救援集锦', cover: 3),
            video('小猪佩奇 游乐场的一天', cover: 4),
          ],
        ),
        12: (
          title: '儿童英语',
          videos: [
            video('Super Simple Songs 英文儿歌', cover: 5),
            video('蓝色小考拉 Penelope 英文版', cover: 6),
          ],
        ),
      });
  }
}

class FakeBiliHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  Duration? connectionTimeout;
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest(url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  // dio 会设置各种可选属性，一律吞掉，绝不能抛 NoSuchMethodError
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  final Uri _url;
  _FakeRequest(this._url);

  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;
  @override
  bool bufferOutput = true;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Uri get uri => _url;

  @override
  Future<HttpClientResponse> close() async {
    if (FakeBili.responseDelay > Duration.zero) {
      await Future<void>.delayed(FakeBili.responseDelay);
    }
    return _route(_url);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  void add(List<int> data) {}
  @override
  void write(Object? object) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> flush() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      null;
}

HttpClientResponse _route(Uri url) {
  if (url.host.contains('hdslb.com')) {
    final name = url.pathSegments.last;
    final f = File('test/fixtures/covers/$name');
    if (f.existsSync()) {
      return _FakeResponse.bytes(f.readAsBytesSync(), 'image/png');
    }
    return _FakeResponse.bytes(const [], 'image/png', status: 404);
  }

  final path = url.path;
  Map<String, dynamic> body;
  if (path.contains('/x/v3/fav/folder/created/list-all')) {
    body = {
      'code': 0,
      'data': {
        'list': [
          for (final e in FakeBili.folders.entries)
            {'id': e.key, 'title': e.value.title, 'media_count': e.value.videos.length},
          {'id': 99, 'title': '默认收藏夹', 'media_count': 3},
        ],
      },
    };
  } else if (path.contains('/x/v3/fav/resource/list')) {
    final id = int.parse(url.queryParameters['media_id']!);
    body = {
      'code': 0,
      'data': {
        'medias': FakeBili.folders[id]?.videos ?? [],
        'has_more': false,
      },
    };
  } else if (path.contains('/x/web-interface/nav')) {
    body = {
      'code': 0,
      'data': {
        'isLogin': true,
        'mid': 10086,
        'uname': '测试家长',
        'wbi_img': {
          'img_url': 'https://i0.hdslb.com/wbi/aabbccddeeff00112233445566778899.png',
          'sub_url': 'https://i0.hdslb.com/wbi/99887766554433221100ffeeddccbbaa.png',
        },
      },
    };
  } else if (path.contains('qrcode/generate')) {
    body = {
      'code': 0,
      'data': {
        'url': 'https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=fakekey',
        'qrcode_key': 'fakekey',
      },
    };
  } else if (path.contains('qrcode/poll')) {
    body = {
      'code': 0,
      'data': {'code': 86101},
    };
  } else if (path.contains('/x/frontend/finger/spi')) {
    body = {
      'code': 0,
      'data': {'b_3': 'fakebuvid3', 'b_4': 'fakebuvid4'},
    };
  } else {
    body = {'code': -404, 'message': 'fake: no route for $path', 'data': null};
  }
  return _FakeResponse.bytes(utf8.encode(jsonEncode(body)), 'application/json');
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int> _bytes;
  final String _mime;
  final int _status;
  _FakeResponse.bytes(this._bytes, this._mime, {int status = 200})
      : _status = status;

  @override
  int get statusCode => _status;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _FakeHeaders()..set('content-type', _mime);

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([_bytes]).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];

  @override
  String? value(String name) => _map[name.toLowerCase()]?.join(', ');

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name.toLowerCase(), () => []).add('$value');

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name.toLowerCase()] = ['$value'];

  @override
  void remove(String name, Object value) => _map.remove(name.toLowerCase());

  @override
  void removeAll(String name) => _map.remove(name.toLowerCase());

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _map.forEach(action);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      null;
}
