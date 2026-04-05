import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../providers/theme_provider.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  UserModel? _user;
  bool _isLoading = true;
  bool _uploadingPic = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseService.updateOnlineStatus(true);
    FirebaseService.updateFcmToken();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FirebaseService.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FirebaseService.updateOnlineStatus(state == AppLifecycleState.resumed);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final user = await FirebaseService.getCurrentUserProfile();
    if (mounted) setState(() { _user = user; _isLoading = false; });
  }

  Future<void> _pickProfilePic() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingPic = true);
    try {
      final url = await FirebaseService.uploadMedia(picked.path, 'image');
      await FirebaseService.updateUserProfile({'profilePicUrl': url});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploadingPic = false);
    }
  }

  void _editProfile() {
    final bioCtrl = TextEditingController(text: _user?.bio);
    final usernameCtrl = TextEditingController(text: _user?.username);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 12),
            TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseService.updateUserProfile({
                    'username': usernameCtrl.text.trim(),
                    'bio': bioCtrl.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  _load();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This will permanently delete your account. Cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseService.deleteCurrentUserAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeProvider.toggle,
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Account')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            onSelected: (v) {
              if (v == 'edit') _editProfile();
              else if (v == 'delete') _deleteAccount();
              else _logout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Avatar
                    Stack(
                      children: [
                        _uploadingPic
                            ? const CircleAvatar(radius: 50, child: CircularProgressIndicator())
                            : GestureDetector(
                                onTap: _pickProfilePic,
                                child: _user?.profilePicUrl.isNotEmpty == true
                                    ? CircleAvatar(
                                        radius: 50,
                                        backgroundImage: CachedNetworkImageProvider(_user!.profilePicUrl),
                                      )
                                    : CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text(
                                          _user?.username.isNotEmpty == true ? _user!.username[0].toUpperCase() : '?',
                                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                              ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_user?.username ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (_user?.bio.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                        child: Text(_user!.bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      ),
                    const SizedBox(height: 8),
                    Text(_user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 32),
                    // Friend requests
                    _SectionHeader(title: 'Friend Requests'),
                    StreamBuilder<List<FriendRequestModel>>(
                      stream: FirebaseService.getFriendRequests(),
                      builder: (context, snap) {
                        final requests = snap.data ?? [];
                        if (requests.isEmpty) return const _EmptyHint(text: 'No pending requests');
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: requests.length,
                          itemBuilder: (_, i) {
                            final req = requests[i];
                            return FutureBuilder<UserModel?>(
                              future: FirebaseService.getUserById(req.fromUid),
                              builder: (_, us) => ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(us.data?.username ?? '...'),
                                subtitle: const Text('sent you a friend request'),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => FirebaseService.acceptFriendRequest(req.id, req.fromUid).then((_) => _load()),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => FirebaseService.rejectFriendRequest(req.id),
                                  ),
                                ]),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 32),
                    _SectionHeader(title: 'Friends'),
                    FutureBuilder<List<UserModel>>(
                      future: FirebaseService.getFriendUsers(),
                      builder: (_, snap) {
                        final friends = snap.data ?? [];
                        if (friends.isEmpty) return const _EmptyHint(text: 'No friends yet — search to add some!');
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: friends.length,
                          itemBuilder: (_, i) {
                            final f = friends[i];
                            return ListTile(
                              leading: Stack(children: [
                                f.profilePicUrl.isNotEmpty
                                    ? CircleAvatar(backgroundImage: CachedNetworkImageProvider(f.profilePicUrl))
                                    : const CircleAvatar(child: Icon(Icons.person)),
                                if (f.isOnline)
                                  const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 6, backgroundColor: Colors.green)),
                              ]),
                              title: Text(f.username),
                              subtitle: Text(f.isOnline ? 'Online' : 'Offline'),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );
}
