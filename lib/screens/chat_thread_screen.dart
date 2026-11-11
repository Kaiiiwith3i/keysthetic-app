import 'package:flutter/material.dart';

import '../widgets/stub_screen.dart';

// TODO(feature agent): build the Chat screen.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({super.key, required this.threadId});
  final int threadId;

  @override
  Widget build(BuildContext context) => StubScreen('Chat', detail: 'threadId: $threadId');
}
