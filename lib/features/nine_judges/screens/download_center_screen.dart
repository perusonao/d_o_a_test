import 'package:dead_or_alive/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadCenterScreen extends StatelessWidget {
  const DownloadCenterScreen({super.key});

  static const _base = 'https://perusonao.github.io/nine-verdicts/downloads/';

  Future<void> _open(BuildContext context, String fileName) async {
    final opened = await launchUrl(
      Uri.parse('$_base$fileName'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ガイド・動画')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'スマホで開いたあと、共有メニューから\n'
                '「ファイルに保存」または「ダウンロード」を選べます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 18),
              _DownloadCard(
                key: const Key('download-how-to'),
                icon: Icons.menu_book_outlined,
                color: AppTheme.savior,
                title: '実際の遊び方',
                detail: 'ルールと勝利条件を7ページで解説',
                format: 'PDF',
                onPressed: () =>
                    _open(context, 'nine-verdicts-how-to-play.pdf'),
              ),
              _DownloadCard(
                key: const Key('download-tutorial'),
                icon: Icons.school_outlined,
                color: AppTheme.eye,
                title: '操作チュートリアル',
                detail: 'EYE・介入・確定・切り札を順番に解説',
                format: 'PDF',
                onPressed: () => _open(context, 'nine-verdicts-tutorial.pdf'),
              ),
              _DownloadCard(
                key: const Key('download-gameplay'),
                icon: Icons.play_circle_outline,
                color: AppTheme.executor,
                title: 'プレイ動画',
                detail: '実際のゲームUIを使った24秒の縦動画',
                format: 'MP4',
                onPressed: () => _open(context, 'nine-verdicts-gameplay.mp4'),
              ),
              _DownloadCard(
                key: const Key('download-tutorial-video'),
                icon: Icons.smart_display_outlined,
                color: AppTheme.eye,
                title: 'チュートリアル動画',
                detail: 'EYE・介入・確定・切り札を実演する動画',
                format: 'MP4',
                onPressed: () =>
                    _open(context, 'nine-verdicts-tutorial-video.mp4'),
              ),
              const SizedBox(height: 12),
              const _DownloadHint(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.format,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String format;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  format,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.open_in_new, size: 18),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DownloadHint extends StatelessWidget {
  const _DownloadHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.accent.withValues(alpha: .4)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.phone_iphone, color: AppTheme.accent, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'iPhone: 開いたファイルの共有ボタンから保存\n'
            'Android: メニューまたはダウンロードボタンから保存',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );
}
