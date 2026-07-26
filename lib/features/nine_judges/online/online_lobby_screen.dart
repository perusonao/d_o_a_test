import 'package:dead_or_alive/features/nine_judges/online/online_room_repository.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _code = TextEditingController();
  final _repository = OnlineRoomRepository();
  String? roomCode;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() operation) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await operation();
      if (mounted) setState(() => roomCode = value ?? _code.text.trim());
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('オンライン対戦 β')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: !FirebaseBootstrap.available
            ? Center(
                child: Text(
                  'Firebaseが未設定のためオンライン対戦を利用できません。\n'
                  '${FirebaseBootstrap.error ?? ''}',
                  textAlign: TextAlign.center,
                ),
              )
            : roomCode == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('create-online-room'),
                    onPressed: busy
                        ? null
                        : () => _run(() => _repository.createRoom()),
                    icon: const Icon(Icons.add),
                    label: const Text('ルームを作る'),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('room-code-input'),
                    controller: _code,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: '6桁のルームコード'),
                  ),
                  FilledButton(
                    key: const Key('join-online-room'),
                    onPressed: busy || _code.text.trim().length != 6
                        ? null
                        : () => _run(() async {
                            await _repository.joinRoom(_code.text.trim());
                            return _code.text.trim();
                          }),
                    child: const Text('参加'),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              )
            : StreamBuilder(
                stream: _repository.watchRoom(roomCode!),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  final playing = data?['status'] == 'playing';
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('ルームコード'),
                      Text(
                        roomCode!,
                        key: const Key('online-room-code'),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: roomCode!)),
                        icon: const Icon(Icons.copy),
                      ),
                      Text(playing ? '2人揃いました' : '相手の参加を待っています…'),
                      const SizedBox(height: 16),
                      const Text(
                        'β版同期基盤は接続済みです。\n'
                        'サーバー権威のゲーム進行はCloud Functions設定後に有効化します。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  );
                },
              ),
      ),
    ),
  );
}
