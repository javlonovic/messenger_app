import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import 'user_search_screen.dart';
import 'chat_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  UserModel? _currentUser;
  List<UserModel> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseService.updateOnlineStatus(true);
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FirebaseService.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseService.updateOnlineStatus(true);
    } else {
      FirebaseService.updateOnlineStatus(false);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await FirebaseService.getCurrentUserProfile();
      final friends = await FirebaseService.getFriendUsers();
      if (mounted) setState(() { _currentUser = user; _friends = friends; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseService.updateOnlineStatus(false);
    } catch (_) {
      // Ignore status update failures on logout.
    }
    await FirebaseService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and profile. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseService.deleteCurrentUserAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    try {
      await FirebaseService.acceptFriendRequest(request.id, request.fromUid);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _declineRequest(FriendRequestModel request) async {
    try {
      await FirebaseService.rejectFriendRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _editProfile() {
    final bioController = TextEditingController(text: _currentUser?.bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseService.updateUserProfile({'bio': bioController.text.trim()});
                if (!mounted) return;
                Navigator.pop(context);
                _loadProfile();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
                );
              },
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messenger'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen()))),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Account')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            onSelected: (v) {
              if (v == 'edit') {
                _editProfile();
              } else if (v == 'delete') {
                _deleteAccount();
              } else if (v == 'logout') {
                _logout();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                    const SizedBox(height: 12),
                    Text(_currentUser?.username ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (_currentUser?.bio.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                        child: Text(_currentUser!.bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      ),
                    const Divider(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sent Requests',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    StreamBuilder<List<FriendRequestModel>>(
                      stream: FirebaseService.getSentFriendRequests(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Could not load sent requests right now.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                        final sentRequests = snapshot.data ?? [];
                        if (sentRequests.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No pending sent requests',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sentRequests.length,
                          itemBuilder: (_, i) {
                            final request = sentRequests[i];
                            return FutureBuilder<UserModel?>(
                              future: FirebaseService.getUserById(request.toUid),
                              builder: (context, userSnap) {
                                final receiverName = userSnap.data?.username ?? 'Unknown user';
                                return ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(receiverName),
                                  subtitle: const Text('Pending'),
                                  trailing: const Icon(Icons.hourglass_top, color: Colors.orange),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Incoming Requests',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    StreamBuilder<List<FriendRequestModel>>(
                      stream: FirebaseService.getFriendRequests(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Could not load requests right now.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                        final requests = snapshot.data ?? [];
                        if (requests.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No pending friend requests',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: requests.length,
                          itemBuilder: (_, i) {
                            final request = requests[i];
                            return FutureBuilder<UserModel?>(
                              future: FirebaseService.getUserById(request.fromUid),
                              builder: (context, userSnap) {
                                final requesterName = userSnap.data?.username ?? 'Unknown user';
                                return ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(requesterName),
                                  subtitle: const Text('sent you a friend request'),
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        onPressed: () => _acceptRequest(request),
                                        icon: const Icon(Icons.check, color: Colors.green),
                                      ),
                                      IconButton(
                                        onPressed: () => _declineRequest(request),
                                        icon: const Icon(Icons.close, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(alignment: Alignment.centerLeft, child: Text('Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    ),
                    if (_friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No friends yet', style: TextStyle(color: Colors.grey)),
                          Text('Find friends to start chatting!', style: TextStyle(color: Colors.grey)),
                        ]),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _friends.length,
                        itemBuilder: (_, i) {
                          final friend = _friends[i];
                          return ListTile(
                            leading: Stack(children: [
                              const CircleAvatar(child: Icon(Icons.person)),
                              if (friend.isOnline)
                                const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 6, backgroundColor: Colors.green)),
                            ]),
                            title: Text(friend.username),
                            subtitle: Text(friend.isOnline ? 'Online' : 'Offline'),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUser: friend))),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
