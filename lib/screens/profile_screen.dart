// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts for consistent typography
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = 'Your Name'; // Holds the user's display name
  // ignore: prefer_final_fields
  bool _loading = false; // Kept for potential future use or other loading states

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _displayName = user?.displayName ?? 'Guest User'; // Set display name from Firebase, default to 'Guest User'
    });
  }

  @override
  void dispose() {
    // No TextEditingController to dispose for the name field anymore
    super.dispose();
  }

  // _saveName method removed as name editing is no longer an option

  Widget _buildProfileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'N/A';

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: const Color(0xFF007AFF), // Use primary blue color
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 24),
        // Display name directly without editing functionality
        Text(
          _displayName,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          userEmail,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        // Removed the edit icon as editing is no longer an option
        if (_loading) // Show linear progress indicator if _loading is true
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),
      ],
    );
  }

  Widget _buildActionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 24), // Increased vertical margin
      elevation: 4, // More pronounced shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset, color: Color(0xFF007AFF)), // Primary blue icon
            title: Text(
              'Change Password',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const Divider(height: 0, indent: 16, endIndent: 16), // Divider with indents
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF007AFF)), // Primary blue icon
            title: Text(
              'About HueAR',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
        title: Text(
          'About HueAR',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: SingleChildScrollView(
          child: Text(
            'HueAR - Experience Colors Without Limits\n\n'
            'HueAR is an accessibility app designed to assist individuals with color vision deficiencies. '
            'Using advanced computer vision, it identifies and announces colors in real-time through your device\'s camera.\n\n'
            'Key Features:\n'
            '• Real-time color detection using camera\n'
            '• Precise color naming with HEX/RGB values\n'
            '• Gallery to store captured color photos\n'
            '• Customizable modes for different color vision needs\n\n'
            'The app helps with daily tasks like selecting clothing, interpreting signals, '
            'and understanding colorful environments by making colors accessible and identifiable.',
            style: GoogleFonts.inter(
              height: 1.4,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
            textAlign: TextAlign.start,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Rounded corners for dialog
        actions: [
          Center(
            child: ElevatedButton( // Use ElevatedButton for a more prominent "Close" button
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF), // Primary blue
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
        title: Text(
          'Profile Settings',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2, // Consistent subtle shadow
        iconTheme: const IconThemeData(color: Colors.black), // Ensure back button is black
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
          children: [
            _buildProfileHeader(),
            _buildActionCard(),
          ],
        ),
      ),
    );
  }
}
