import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter/material.dart';

/// Section 13: free-text list — only games with `feedbackComment` or
/// `notes`. Read-only: no editing/deleting from the admin screen.
class AdminFeedbackTab extends StatelessWidget {
  const AdminFeedbackTab({required this.records, required this.anonymizer, super.key});

  final List<PlaytestRecord> records;
  final TesterAnonymizer anonymizer;

  @override
  Widget build(BuildContext context) {
    final withText = records.where((r) {
      final s = r.session;
      return (s.feedbackComment ?? '').trim().isNotEmpty || s.notes.trim().isNotEmpty;
    }).toList();

    if (withText.isEmpty) {
      return const Center(
        child: Text(
          '自由記述のあるログはありません',
          key: Key('admin-feedback-empty'),
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      key: const Key('admin-feedback-list'),
      padding: const EdgeInsets.all(12),
      itemCount: withText.length,
      itemBuilder: (context, index) {
        final record = withText[index];
        final s = record.session;
        final label = anonymizer.label(s.testerId);
        final text = (s.feedbackComment ?? '').trim().isNotEmpty
            ? s.feedbackComment!.trim()
            : s.notes.trim();
        final truncated = text.length > 120 ? '${text.substring(0, 120)}…' : text;
        return Card(
          key: Key('admin-feedback-${s.gameId}'),
          color: Colors.white10,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            onTap: () => _showFullText(context, s.gameId, text),
            title: Text(
              '$label  #${s.playNumber ?? '-'}  '
              'fun:${s.funRating ?? '-'} rule:${s.ruleUnderstandingRating ?? '-'} '
              'replay:${s.replayIntentRating ?? '-'}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            subtitle: Text(
              truncated,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showFullText(BuildContext context, String gameId, String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15151C),
        title: Text('gameId: $gameId', style: const TextStyle(color: Colors.white, fontSize: 13)),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
