import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/analysis_export_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/widgets/analysis_findings_view.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/widgets/analysis_summary_view.dart';
import 'package:flutter/material.dart';

/// Section 8: サマリー/Markdown/JSON/注目点/フィードバック preview tabs, plus
/// the copy/download actions from section 7. Long JSON/Markdown text is
/// rendered line-by-line through `ListView.builder` (lazy) rather than one
/// giant `Text` widget, per section 8's "画面が固まらないように" requirement.
class AnalysisReportPreview extends StatefulWidget {
  const AnalysisReportPreview({required this.report, super.key});

  final AnalysisReport report;

  @override
  State<AnalysisReportPreview> createState() => _AnalysisReportPreviewState();
}

class _AnalysisReportPreviewState extends State<AnalysisReportPreview>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 5, vsync: this);
  late String _markdown = AnalysisExportService.buildMarkdown(widget.report);
  late String _json = AnalysisExportService.buildJson(widget.report);
  bool _markdownRendered = false;
  bool _jsonWrap = false;

  @override
  void didUpdateWidget(covariant AnalysisReportPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.report, widget.report)) {
      _markdown = AnalysisExportService.buildMarkdown(widget.report);
      _json = AnalysisExportService.buildJson(widget.report);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String label) async {
    await AnalysisExportService.copyToClipboard(text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$labelをクリップボードへコピーしました')));
  }

  void _download(void Function() action, String label) {
    try {
      action();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$labelのダウンロードを開始しました')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$labelのダウンロードに失敗しました。コピーをご利用ください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'サマリー'),
          Tab(text: 'Markdown'),
          Tab(text: 'JSON'),
          Tab(text: '注目点'),
          Tab(text: 'フィードバック'),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              key: const Key('analysis-copy-markdown'),
              onPressed: () => _copy(_markdown, 'Markdown'),
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Markdownをコピー'),
            ),
            OutlinedButton.icon(
              key: const Key('analysis-copy-json'),
              onPressed: () => _copy(_json, 'JSON'),
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('JSONをコピー'),
            ),
            OutlinedButton.icon(
              key: const Key('analysis-download-markdown'),
              onPressed: () => _download(
                () => AnalysisExportService.downloadMarkdown(widget.report),
                'Markdown',
              ),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Markdownをダウンロード'),
            ),
            OutlinedButton.icon(
              key: const Key('analysis-download-json'),
              onPressed: () => _download(
                () => AnalysisExportService.downloadJson(widget.report),
                'JSON',
              ),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('JSONをダウンロード'),
            ),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            AnalysisSummaryView(report: widget.report),
            _markdownTab(),
            _jsonTab(),
            AnalysisFindingsView(findings: widget.report.findings),
            _feedbackTab(),
          ],
        ),
      ),
    ],
  );

  Widget _markdownTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Text('表示: ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ChoiceChip(
              key: const Key('analysis-markdown-raw'),
              label: const Text('等幅テキスト'),
              selected: !_markdownRendered,
              onSelected: (_) => setState(() => _markdownRendered = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const Key('analysis-markdown-rendered'),
              label: const Text('プレビュー'),
              selected: _markdownRendered,
              onSelected: (_) => setState(() => _markdownRendered = true),
            ),
          ],
        ),
      ),
      Expanded(
        child: _markdownRendered ? _renderedMarkdown() : _rawLines(_markdown, monospace: true),
      ),
    ],
  );

  Widget _renderedMarkdown() {
    final lines = _markdown.split('\n');
    return ListView.builder(
      key: const Key('analysis-markdown-rendered-view'),
      padding: const EdgeInsets.all(12),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        if (line.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        if (line.startsWith('- ') || line.startsWith('  > ')) {
          return Padding(
            padding: const EdgeInsets.only(left: 12, top: 1, bottom: 1),
            child: Text(line, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          );
        }
        if (line.trim().isEmpty) return const SizedBox(height: 6);
        return Text(line, style: const TextStyle(color: Colors.white70, fontSize: 13));
      },
    );
  }

  Widget _jsonTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Text('折り返し: ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            Switch(
              key: const Key('analysis-json-wrap-toggle'),
              value: _jsonWrap,
              onChanged: (v) => setState(() => _jsonWrap = v),
            ),
          ],
        ),
      ),
      Expanded(child: _rawLines(_json, monospace: true, wrap: _jsonWrap)),
    ],
  );

  Widget _rawLines(String text, {required bool monospace, bool wrap = true}) {
    final lines = text.split('\n');
    final list = ListView.builder(
      key: ValueKey('raw-lines-${text.length}'),
      padding: const EdgeInsets.all(12),
      itemCount: lines.length,
      itemBuilder: (context, index) => Text(
        lines[index],
        softWrap: wrap,
        overflow: wrap ? TextOverflow.clip : TextOverflow.visible,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontFamily: monospace ? 'monospace' : null,
        ),
      ),
    );
    if (wrap) return list;
    return Scrollbar(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 2000, child: list)));
  }

  Widget _feedbackTab() {
    final feedback = widget.report.feedback;
    if (feedback.isEmpty) {
      return const Center(
        child: Text(
          '自由記述はありません',
          key: Key('analysis-feedback-empty'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      key: const Key('analysis-feedback-list'),
      padding: const EdgeInsets.all(12),
      itemCount: feedback.length,
      itemBuilder: (context, index) {
        final f = feedback[index];
        final comment = (f['feedbackComment'] ?? f['notes'] ?? '').toString();
        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${f['anonymousPlayerLabel']} (#${f['playNumber']}) '
                  'fun:${f['fun'] ?? '-'} rule:${f['ruleUnderstanding'] ?? '-'} replay:${f['replayIntent'] ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(comment, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }
}
