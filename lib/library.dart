import 'api/bili_client.dart';
import 'app_settings.dart';
import 'models.dart';

/// 预设体验收藏夹（公开收藏夹的 media_id），用户没配置收藏夹时快速体验
const kTrialFolderIds = [4083295160, 4126710760, 4062316360];

class Library {
  Library._();
  static final Library i = Library._();

  List<FavFolder> folders = [];
  final Map<int, List<VideoItem>> cache = {};

  Future<List<FavFolder>> _fetchFolders() async {
    if (AppSettings.i.trialMode) {
      return [
        for (final id in kTrialFolderIds) await BiliClient.i.favFolderInfo(id),
      ];
    }
    return BiliClient.i.kidFavFolders();
  }

  Future<void> loadFolders({bool force = false}) async {
    if (folders.isNotEmpty && !force) return;
    folders = await _fetchFolders();
  }

  /// 全量重新拉取，成功后一次性替换，避免刷新期间列表清空
  Future<void> refresh() async {
    final newFolders = await _fetchFolders();
    final newCache = <int, List<VideoItem>>{};
    for (final f in newFolders) {
      newCache[f.id] = await BiliClient.i.favVideos(f.id);
    }
    folders = newFolders;
    cache
      ..clear()
      ..addAll(newCache);
  }

  Future<List<VideoItem>> videosOf(FavFolder f) async =>
      cache[f.id] ??= await BiliClient.i.favVideos(f.id);

  Future<void> ensureAll() async {
    await loadFolders();
    for (final f in folders) {
      await videosOf(f);
    }
  }

  List<VideoItem> all() {
    final out = <VideoItem>[];
    final seen = <String>{};
    for (final f in folders) {
      for (final v in cache[f.id] ?? const <VideoItem>[]) {
        if (seen.add(v.bvid)) out.add(v);
      }
    }
    return out;
  }

  void reset() {
    folders = [];
    cache.clear();
  }
}
