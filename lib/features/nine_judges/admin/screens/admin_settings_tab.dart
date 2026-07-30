import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:flutter/material.dart';

/// Section 5/18/21: connection info + the explicit tutorial-telemetry
/// disclaimer (section 18 — must never fabricate an aggregate for data that
/// isn't actually in Firestore).
class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({
    required this.userEmail,
    required this.projectId,
    required this.lastUpdated,
    required this.loadedCount,
    super.key,
  });

  final String userEmail;
  final String projectId;
  final DateTime? lastUpdated;
  final int loadedCount;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('admin-settings-list'),
    padding: const EdgeInsets.all(16),
    children: [
      _row('ログイン中アカウント', userEmail),
      _row('Firebase projectId', projectId),
      _row('rulesVersion', NineJudgesConfig.rulesVersion),
      _row('gameVersion', NineJudgesConfig.gameVersion),
      _row('testCohort', NineJudgesConfig.testCohort),
      _row('読み込み済みゲーム数', '$loadedCount'),
      _row(
        '最終更新',
        lastUpdated == null
            ? '-'
            : '${lastUpdated!.hour.toString().padLeft(2, '0')}:'
                  '${lastUpdated!.minute.toString().padLeft(2, '0')}:'
                  '${lastUpdated!.second.toString().padLeft(2, '0')}',
      ),
      const Divider(color: Colors.white24, height: 32),
      const Text(
        'チュートリアル計測データについて',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'チュートリアルデータは現在Firestoreへ送信されていません。'
        'このタブに集計値は表示されません(端末内Hiveストレージにのみ保存されています)。',
        key: Key('admin-tutorial-not-sent-notice'),
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const Divider(color: Colors.white24, height: 32),
      const Text(
        'SNS向けプロモーション動画',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        '固定シード・JSON台本(assets/promo/default_script.json)で毎回同じ映像を'
        '自動再生します。録画してX/TikTok/YouTube Shorts向けの紹介動画を作成できます。',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('admin-open-promo'),
        onPressed: () => Navigator.of(context).pushNamed('/promo'),
        icon: const Text('🎬'),
        label: const Text('プロモーション動画'),
      ),
      const Divider(color: Colors.white24, height: 32),
      const Text(
        '管理画面は読み取り専用です',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'ログの編集・削除、コメントの編集、管理者の追加/削除はこの画面から行えません。',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
      ],
    ),
  );
}
