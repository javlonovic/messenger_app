import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import 'user_profile_view_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});
  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _searched = false;

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty) return;
    setState(() { _isLoading = true; _searched = true; });
    try {
      final results = await FirebaseService.searchUsers(_searchController.text.trim());
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search for Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a username to find your friends',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_searched
                    ? const Center(child: Text('Search for friends by username'))
                    : _results.isEmpty
                        ? const Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.person_search, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No Users Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('Try searching with a different username', style: TextStyle(color: Colors.grey)),
                            ]),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final user = _results[i];
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(user.username),
                                subtitle: Text(user.bio.isNotEmpty ? user.bio : user.email),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileViewScreen(user: user))),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
