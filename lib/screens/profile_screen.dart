// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    final newName = _nameController.text.trim();

    if (user != null && newName.isNotEmpty) {
      setState(() => _loading = true);
      try {
        await user.updateDisplayName(newName);
        await user.reload();
        setState(() => _editingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: ${e.toString()}')),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 60,
          backgroundColor: Colors.blueGrey,
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 24),
        _editingName
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _saveName,
                    ),
                    border: const UnderlineInputBorder(),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : 'Your Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => setState(() => _editingName = true),
                  ),
                ],
              ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }

  Widget _buildActionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Hue AR'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Hue AR', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Text(
            'HueAR - See the World in True Color\n\n'
            'An Augmented Reality app that assists individuals with color blindness '
            'by adjusting and labeling colors in real time through your camera. '
            'Features include color identification, correction filters, and '
            'enhanced contrast for better color distinction.',
            style: TextStyle(
              height: 1.4,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildActionCard(),
          ],
        ),
      ),
    );
  }
}