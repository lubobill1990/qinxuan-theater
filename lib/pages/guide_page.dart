import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_settings.dart';

const _kGuideShownKey = 'guide_shown';

Future<bool> guideShown() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kGuideShownKey) ?? false;
}

Future<void> markGuideShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kGuideShownKey, true);
}

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuideStep {
  final IconData icon;
  final String title;
  final String body;
  const _GuideStep(this.icon, this.title, this.body);
}

List<_GuideStep> get _steps {
  final k = AppSettings.i.kidKeywords.first;
  final all = AppSettings.i.kidKeywords.join('/');
  return [
    _GuideStep(
      CupertinoIcons.folder_fill_badge_plus,
      '第一步：在哔哩哔哩里建收藏夹',
      '打开哔哩哔哩 App 或网页，创建名字以「$all」开头的收藏夹。\n\n'
          '例如：$k动画、$k英语、$k科普。\n'
          '可以建多个，方便分类管理。\n关键字可以在设置里修改。',
    ),
    _GuideStep(
      CupertinoIcons.star_fill,
      '第二步：收藏想给孩子看的视频',
      '在哔哩哔哩里刷到适合孩子的视频时，把它收藏进「$k」收藏夹。\n\n'
          '以后随时增删收藏，就能控制孩子能看到的内容。',
    ),
    const _GuideStep(
      CupertinoIcons.checkmark_shield_fill,
      '第三步：孩子只看你选的',
      '回到亲选小剧场，下拉刷新首页，收藏的视频就会出现。\n\n'
          '这里没有弹幕、评论和推荐，孩子只能看到你挑选的视频，专注不迷路。',
    ),
  ];
}

class _GuidePageState extends State<GuidePage> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() {
    markGuideShown();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: _finish,
                child: const Text('跳过', style: TextStyle(fontSize: 15)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) {
                  final s = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon,
                              size: 52, color: CupertinoColors.activeBlue),
                        ),
                        const SizedBox(height: 32),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        Text(s.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: CupertinoColors.secondaryLabel)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey3,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(14),
                  onPressed: last
                      ? _finish
                      : () => _pc.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut),
                  child: Text(last ? '开始使用' : '下一步'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showGuide(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const GuidePage()),
  );
}
