import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  const ChatScreen({super.key, required this.otherUser});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _editingMessageId;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    if (_editingMessageId != null) {
      final chatId = [FirebaseService.currentUid!, widget.otherUser.uid]..sort();
      await FirebaseService.editMessage(chatId.join('_'), _editingMessageId!, text);
      setState(() => _editingMessageId = null);
    } else {
      await FirebaseService.sendMessage(widget.otherUser.uid, text);
    }
    _scrollToBottom();
  }

  void _showMessageOptions(MessageModel message) {
    final isMe = message.senderId == FirebaseService.currentUid;
    final chatId = [FirebaseService.currentUid!, widget.otherUser.uid]..sort();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Message Info'),
        content: Text(message.text),
        actions: [
          if (isMe) TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _editingMessageId = message.id; _messageController.text = message.text; });
            },
            child: const Text('Edit'),
          ),
          if (isMe) TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.deleteMessage(chatId.join('_'), message.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUser.username, style: const TextStyle(fontSize: 16)),
                Text(widget.otherUser.isOnline ? 'Online' : 'Offline', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: FirebaseService.getMessages(widget.otherUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No messages yet', style: TextStyle(color: Colors.grey)),
                      Text('Start your conversation!', style: TextStyle(color: Colors.grey)),
                    ]),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == FirebaseService.currentUid;
                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(msg),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[200],
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_editingMessageId != null)
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('Editing message', style: TextStyle(color: Colors.blue)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _editingMessageId = null; _messageController.clear(); })),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 8, right: 8, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
