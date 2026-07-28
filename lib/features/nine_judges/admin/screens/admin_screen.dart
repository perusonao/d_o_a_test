import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_dashboard_screen.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_session_controller.dart';
import 'package:flutter/material.dart';

/// Entry point for the `/admin` route (section 2/3). Reachable only by
/// typing the URL directly — no normal player screen links here. Renders
/// exactly one of the states section 3/21 require; never shows any
/// playtest data until [AdminSessionStatus.admin] is reached.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.controller});

  /// Injectable for tests.
  final AdminSessionController? controller;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminSessionController _controller =
      widget.controller ?? AdminSessionController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    switch (_controller.status) {
      case AdminSessionStatus.initializing:
        return const _GateMessage(
          key: Key('admin-gate-initializing'),
          icon: Icons.hourglass_top,
          title: 'Firebase接続を確認しています…',
          showProgress: true,
        );
      case AdminSessionStatus.initFailed:
        return _GateMessage(
          key: const Key('admin-gate-init-failed'),
          icon: Icons.cloud_off,
          title: 'Firebaseの初期化に失敗しました',
          detail: _controller.errorDetail,
          actions: [
            FilledButton(
              key: const Key('admin-retry'),
              onPressed: _controller.retry,
              child: const Text('再試行'),
            ),
          ],
        );
      case AdminSessionStatus.signedOut:
        return _GateMessage(
          key: const Key('admin-gate-signed-out'),
          icon: Icons.admin_panel_settings_outlined,
          title: '9人の審判 / 外部テスト管理画面',
          subtitle: '管理者はGoogleアカウントでログインしてください。',
          actions: [
            FilledButton.icon(
              key: const Key('admin-google-sign-in'),
              onPressed: _controller.signingIn ? null : _controller.signIn,
              icon: _controller.signingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Googleでログイン'),
            ),
          ],
        );
      case AdminSessionStatus.googleSignInFailed:
        return _GateMessage(
          key: const Key('admin-gate-signin-failed'),
          icon: Icons.error_outline,
          title: 'Googleログインに失敗しました',
          detail: _controller.errorDetail,
          actions: [
            FilledButton.icon(
              key: const Key('admin-google-sign-in-retry'),
              onPressed: _controller.signingIn ? null : _controller.signIn,
              icon: const Icon(Icons.login),
              label: const Text('もう一度ログイン'),
            ),
          ],
        );
      case AdminSessionStatus.checkingAdmin:
        return const _GateMessage(
          key: Key('admin-gate-checking'),
          icon: Icons.hourglass_top,
          title: '管理者権限を確認しています…',
          showProgress: true,
        );
      case AdminSessionStatus.notAdmin:
        return _GateMessage(
          key: const Key('admin-gate-not-admin'),
          icon: Icons.block,
          title: 'このアカウントには管理権限がありません',
          subtitle: _controller.user?.email,
          actions: [
            OutlinedButton(
              key: const Key('admin-logout'),
              onPressed: _controller.signOut,
              child: const Text('ログアウト'),
            ),
          ],
        );
      case AdminSessionStatus.adminCheckFailed:
        return _GateMessage(
          key: const Key('admin-gate-check-failed'),
          icon: Icons.warning_amber_outlined,
          title: '管理者権限の確認中にエラーが発生しました',
          subtitle: 'Firestoreへの接続、または権限設定をご確認ください。',
          detail: _controller.errorDetail,
          actions: [
            FilledButton(
              key: const Key('admin-retry'),
              onPressed: _controller.retry,
              child: const Text('再試行'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const Key('admin-logout'),
              onPressed: _controller.signOut,
              child: const Text('ログアウト'),
            ),
          ],
        );
      case AdminSessionStatus.admin:
        return AdminDashboardScreen(
          userEmail: _controller.user?.email ?? '-',
          onLogout: _controller.signOut,
        );
    }
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.detail,
    this.actions = const [],
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? detail;
  final List<Widget> actions;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (showProgress) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
            if (detail != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text(
                  '詳細情報(デバッグ用)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      detail!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ],
        ),
      ),
    ),
  );
}
