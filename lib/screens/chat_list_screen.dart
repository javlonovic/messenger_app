import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../utils/time_utils.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';
import 'profile_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.currentUid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.streamChatList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No chats yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Find friends to chat'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final chat = chats[i];
              final participants = List<String>.from(chat['participants'] ?? []);
              final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
              final unread = (chat['unread_$uid'] ?? 0) as int;
              final lastMsg = chat['lastMessage'] as String? ?? '';
              final lastTime = chat['lastMessageTime'] != null
                  ? (chat['lastMessageTime'] as dynamic).toDate() as DateTime
                  : null;
              return FutureBuilder<UserModel?>(
                future: FirebaseService.getUserById(otherUid),
                builder: (context, userSnap) {
                  final user = userSnap.data;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: _Avatar(url: user?.profilePicUrl, name: user?.username),
                    title: Text(
                      user?.username ?? '...',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread > 0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                        fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (lastTime != null)
                          Text(
                            TimeUtils.formatChatTimestamp(lastTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                          ),
                        if (unread > 0) ...[
                          const SizedBox(height: 4),
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (user != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUser: user)));
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String? name;
  const _Avatar({this.url, this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
