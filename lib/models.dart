class FavFolder {
  final int id;
  final String title;
  final int count;
  FavFolder({required this.id, required this.title, required this.count});

  factory FavFolder.fromJson(Map<String, dynamic> j) => FavFolder(
        id: j['id'] as int,
        title: j['title'] as String,
        count: (j['media_count'] ?? 0) as int,
      );
}

class VideoItem {
  final String bvid;
  final String title;
  final String cover;
  final int duration;
  final String upper;
  VideoItem({
    required this.bvid,
    required this.title,
    required this.cover,
    required this.duration,
    required this.upper,
  });

  factory VideoItem.fromFavJson(Map<String, dynamic> j) => VideoItem(
        bvid: j['bvid'] as String,
        title: j['title'] as String,
        cover: (j['cover'] ?? '') as String,
        duration: (j['duration'] ?? 0) as int,
        upper: (j['upper']?['name'] ?? '') as String,
      );
}

class Episode {
  final String bvid;
  final int cid;
  final String title;
  final String cover;
  Episode({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.cover,
  });
}
