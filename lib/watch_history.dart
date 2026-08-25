import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String key;
  final String title;
  final String cover;
  final String epBvid;
  final int cid;
  final String epTitle;
  final int positionMs;
  final int durationMs;
  final int updatedAt;

  /// 各集进度表：'epBvid:cid' → positionMs（看完的集记 0）
  final Map<String, int> epPositions;

  HistoryEntry({
    required this.key,
    required this.title,
    required this.cover,
    required this.epBvid,
    required this.cid,
    required this.epTitle,
    required this.positionMs,
    required this.durationMs,
    int? updatedAt,
    Map<String, int>? epPositions,
  })  : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
        epPositions = epPositions ?? {};

  int posFor(String epBvid, int cid) => epPositions['$epBvid:$cid'] ?? 0;

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'cover': cover,
        'epBvid': epBvid,
        'cid': cid,
        'epTitle': epTitle,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt,
        'epPositions': epPositions,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        key: j['key'] as String,
        title: j['title'] as String,
        cover: j['cover'] as String,
        epBvid: j['epBvid'] as String,
        cid: j['cid'] as int,
        epTitle: j['epTitle'] as String,
        positionMs: j['positionMs'] as int,
        durationMs: j['durationMs'] as int,
        updatedAt: j['updatedAt'] as int,
        epPositions: (j['epPositions'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as int)),
      );
}

String fmtMs(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String relativeDay(int epochMs) {
  final then = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final now = DateTime.now();
  final d = DateTime(now.year, now.month, now.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (d <= 0) return '今天';
  if (d == 1) return '昨天';
  return '$d 天前';
}

class WatchHistory {
  WatchHistory._();
  static final WatchHistory i = WatchHistory._();

  final ValueNotifier<int> version = ValueNotifier(0);
  List<HistoryEntry> entries = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('watch_history');
    if (raw != null) {
      entries = (jsonDecode(raw) as List)
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'watch_history', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  HistoryEntry? find(String key) {
    for (final e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  Future<void> record(HistoryEntry e) async {
    await load();
    // 继承同合集里其他集的进度，并更新当前集的
    final positions = {...?find(e.key)?.epPositions, ...e.epPositions};
    positions['${e.epBvid}:${e.cid}'] = e.positionMs;
    final merged = HistoryEntry(
      key: e.key,
      title: e.title,
      cover: e.cover,
      epBvid: e.epBvid,
      cid: e.cid,
      epTitle: e.epTitle,
      positionMs: e.positionMs,
      durationMs: e.durationMs,
      updatedAt: e.updatedAt,
      epPositions: positions,
    );
    entries.removeWhere((x) => x.key == e.key);
    entries.insert(0, merged);
    if (entries.length > 200) entries.removeRange(200, entries.length);
    version.value++;
    await _save();
    debugPrint('[history] saved ${e.key} pos=${e.positionMs} n=${entries.length}');
  }

  Future<void> clear() async {
    entries = [];
    version.value++;
    await _save();
  }
}
