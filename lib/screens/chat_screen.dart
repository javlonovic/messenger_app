import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _imagePicker = ImagePicker();
  String? _editingMessageId;
  bool _isSending = false;
  int _lastMessageCount = 0;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      _messageController.clear();
      if (_editingMessageId != null) {
        final uid = FirebaseService.currentUid;
        if (uid == null) throw Exception('Please login again.');
        final chatId = [uid, widget.otherUser.uid]..sort();
        await FirebaseService.editMessage(chatId.join('_'), _editingMessageId!, text);
        if (mounted) setState(() => _editingMessageId = null);
      } else {
        await FirebaseService.sendMessage(widget.otherUser.uid, text: text);
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final picked = isVideo
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final mediaType = isVideo ? 'video' : 'image';
      final mediaUrl = await FirebaseService.uploadChatMedia(
        receiverId: widget.otherUser.uid,
        filePath: picked.path,
        mediaType: mediaType,
      );
      final caption = _messageController.text.trim();
      _messageController.clear();
      await FirebaseService.sendMessage(
        widget.otherUser.uid,
        text: caption,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send media: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildMedia(MessageModel message, bool isMe) {
    if (message.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220, maxHeight: 280),
          child: Image.network(
            message.mediaUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Image unavailable'),
            ),
          ),
        ),
      );
    }
    if (message.hasVideo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              color: isMe ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              'Video message',
              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showMessageOptions(MessageModel message) {
    final isMe = message.senderId == FirebaseService.currentUid;
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    final chatId = [uid, widget.otherUser.uid]..sort();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Message Info'),
        content: Text(message.text.isEmpty ? 'Media message' : message.text),
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
              try {
                await FirebaseService.deleteMessage(chatId.join('_'), message.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
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
                if (_lastMessageCount != messages.length) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (msg.hasImage || msg.hasVideo)
                                _buildMedia(msg, isMe),
                              if (msg.text.isNotEmpty) ...[
                                if (msg.hasImage || msg.hasVideo)
                                  const SizedBox(height: 8),
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                    decoration: const InputDecoration(
                      hintText: 'Type a message or caption...',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.blue),
                  onPressed: _isSending ? null : () => _pickAndSendMedia(isVideo: false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.blue),
                  onPressed: _isSending ? null : () => _pickAndSendMedia(isVideo: true),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
