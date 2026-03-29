import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  final UserModel user;
  const UserProfileViewScreen({super.key, required this.user});
  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  String _friendshipStatus = 'none';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriendshipStatus();
  }

  Future<void> _loadFriendshipStatus() async {
    final status = await FirebaseService.getFriendshipStatus(widget.user.uid);
    if (mounted) setState(() { _friendshipStatus = status; _isLoading = false; });
  }

  Future<void> _sendFriendRequest() async {
    try {
      await FirebaseService.sendFriendRequest(widget.user.uid);
      if (mounted) setState(() => _friendshipStatus = 'pending');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend Request Sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    await FirebaseService.acceptFriendRequest(requestId, widget.user.uid);
    if (mounted) setState(() => _friendshipStatus = 'accepted');
  }

  Future<void> _declineRequest(String requestId) async {
    await FirebaseService.rejectFriendRequest(requestId);
    if (mounted) setState(() => _friendshipStatus = 'rejected');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request declined')));
  }

  Widget _buildActionButton() {
    if (_isLoading) return const CircularProgressIndicator();
    switch (_friendshipStatus) {
      case 'friends':
      case 'accepted':
        return ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUser: widget.user))),
          icon: const Icon(Icons.chat),
          label: const Text('Start Chat'),
        );
      case 'pending':
        return const ElevatedButton(onPressed: null, child: Text('Friend Request Sent'));
      default:
        return ElevatedButton.icon(
          onPressed: _sendFriendRequest,
          icon: const Icon(Icons.person_add),
          label: const Text('Send Friend Request'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.username)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)),
            const SizedBox(height: 16),
            Text(widget.user.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (widget.user.bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                child: Text(widget.user.bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 24),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }
}
