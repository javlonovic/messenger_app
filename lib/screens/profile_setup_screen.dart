import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String uid;
  final String email;
  const ProfileSetupScreen({super.key, required this.uid, required this.email});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;

  String _readableProfileError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied profile creation. Update Firestore Rules to allow signed-in users to create their own user document.';
    }
    return 'Failed to create profile. Please try again.';
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = UserModel(
        uid: widget.uid,
        username: _usernameController.text.trim(),
        email: widget.email,
        bio: _bioController.text.trim(),
        createdAt: DateTime.now(),
      );
      await FirebaseService.createUserProfile(user);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_readableProfileError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v!.isEmpty ? 'Enter a username' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createProfile,
                      child: const Text('Create Profile'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
