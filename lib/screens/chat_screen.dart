import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../utils/time_utils.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  const ChatScreen({super.key, required this.otherUser});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  String? _editingMessageId;
  MessageModel? _replyTo;
  bool _isSending = false;
  bool _showEmoji = false;
  Timer? _typingTimer;
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    _chatId = FirebaseService.getChatId(FirebaseService.currentUid!, widget.otherUser.uid);
    FirebaseService.markMessagesRead(_chatId, widget.otherUser.uid);
    _msgCtrl.addListener(_onTyping);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    FirebaseService.setTyping(_chatId, false);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTyping() {
    FirebaseService.setTyping(_chatId, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      FirebaseService.setTyping(_chatId, false);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    FirebaseService.setTyping(_chatId, false);
    try {
      if (_editingMessageId != null) {
        await FirebaseService.editMessage(_chatId, _editingMessageId!, text);
        setState(() => _editingMessageId = null);
      } else {
        await FirebaseService.sendMessage(
          widget.otherUser.uid,
          text: text,
          replyToId: _replyTo?.id,
          replyToText: _replyTo?.text.isNotEmpty == true ? _replyTo!.text : '📷 Media',
        );
        setState(() => _replyTo = null);
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickMedia({required bool isVideo}) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final picked = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      final mediaType = isVideo ? 'video' : 'image';
      final url = await FirebaseService.uploadChatMedia(
        receiverId: widget.otherUser.uid,
        filePath: picked.path,
        mediaType: mediaType,
      );
      await FirebaseService.sendMessage(
        widget.otherUser.uid,
        text: _msgCtrl.text.trim(),
        mediaUrl: url,
        mediaType: mediaType,
      );
      _msgCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessageOptions(MessageModel msg) {
    final isMe = msg.senderId == FirebaseService.currentUid;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reaction bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((e) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      FirebaseService.toggleReaction(_chatId, msg.id, e);
                    },
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
            if (isMe && !msg.isDeleted)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessageId = msg.id;
                    _msgCtrl.text = msg.text;
                  });
                },
              ),
            if (isMe && !msg.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseService.deleteMessage(_chatId, msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<UserModel?>(
          stream: FirebaseService.streamUser(widget.otherUser.uid),
          builder: (context, snap) {
            final user = snap.data ?? widget.otherUser;
            return Row(
              children: [
                _buildAvatar(user, radius: 18),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    StreamBuilder<bool>(
                      stream: FirebaseService.streamTyping(_chatId, widget.otherUser.uid),
                      builder: (context, typingSnap) {
                        if (typingSnap.data == true) {
                          return Text('typing...', style: TextStyle(fontSize: 12, color: colorScheme.primary));
                        }
                        return Text(
                          user.isOnline ? 'Online' : TimeUtils.formatLastSeen(user.lastSeen),
                          style: TextStyle(fontSize: 12, color: user.isOnline ? Colors.green : Colors.grey),
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: FirebaseService.getMessages(widget.otherUser.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Say hello!', style: TextStyle(color: Colors.grey[500])),
                    ]),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isMe = msg.senderId == FirebaseService.currentUid;
                    final showDate = i == 0 ||
                        !_sameDay(msgs[i - 1].timestamp, msg.timestamp);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.timestamp),
                        GestureDetector(
                          onLongPress: () => _showMessageOptions(msg),
                          child: _MessageBubble(
                            msg: msg,
                            isMe: isMe,
                            onReactionTap: (e) => FirebaseService.toggleReaction(_chatId, msg.id, e),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_replyTo != null) _ReplyBar(msg: _replyTo!, onCancel: () => setState(() => _replyTo = null)),
          if (_editingMessageId != null)
            Container(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Editing message'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() { _editingMessageId = null; _msgCtrl.clear(); }),
                  ),
                ],
              ),
            ),
          _InputBar(
            controller: _msgCtrl,
            isSending: _isSending,
            showEmoji: _showEmoji,
            onSend: _sendMessage,
            onImage: () => _pickMedia(isVideo: false),
            onVideo: () => _pickMedia(isVideo: true),
            onEmojiToggle: () => setState(() => _showEmoji = !_showEmoji),
          ),
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  _msgCtrl.text += emoji.emoji;
                  _msgCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _msgCtrl.text.length),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildAvatar(UserModel user, {double radius = 20}) {
    if (user.profilePicUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(user.profilePicUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final void Function(String) onReactionTap;
  const _MessageBubble({required this.msg, required this.isMe, required this.onReactionTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? colorScheme.primary : colorScheme.surfaceVariant;
    final textColor = isMe ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: msg.isDeleted ? Colors.grey[300] : bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.replyToText != null && !msg.isDeleted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        msg.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)),
                      ),
                    ),
                  if (msg.hasImage && !msg.isDeleted)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: msg.mediaUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                    ),
                  if (msg.hasVideo && !msg.isDeleted)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.videocam, color: textColor),
                      const SizedBox(width: 6),
                      Text('Video', style: TextStyle(color: textColor)),
                    ]),
                  if (msg.text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: (msg.hasImage || msg.hasVideo) ? 6 : 0),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isDeleted ? Colors.grey[600] : textColor,
                          fontStyle: msg.isDeleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TimeUtils.formatMessageTime(msg.timestamp),
                        style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: msg.isRead ? Colors.lightBlueAccent : textColor.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 4,
                children: msg.reactions.entries.map((e) {
                  return GestureDetector(
                    onTap: () => onReactionTap(e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text('${e.key} ${e.value.length}', style: const TextStyle(fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final MessageModel msg;
  final VoidCallback onCancel;
  const _ReplyBar({required this.msg, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.reply, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg.text.isNotEmpty ? msg.text : '📷 Media',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancel),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool showEmoji;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onVideo;
  final VoidCallback onEmojiToggle;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.showEmoji,
    required this.onSend,
    required this.onImage,
    required this.onVideo,
    required this.onEmojiToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        left: 8, right: 8, top: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -1))],
      ),
      child: Row(
        children: [
          IconButton(icon: Icon(showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined), onPressed: onEmojiToggle),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Message...', isDense: true),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(icon: const Icon(Icons.image_outlined), onPressed: isSending ? null : onImage),
          isSending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                  onPressed: onSend,
                ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today) label = 'Today';
    else if (d == yesterday) label = 'Yesterday';
    else label = '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}
