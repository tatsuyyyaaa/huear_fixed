import 'dart:io'; // Required for File
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:huear_fixed/screens/profile_screen.dart';
import 'package:huear_fixed/screens/camera_screen.dart'; // Your ARColorDetectorScreen
import 'package:huear_fixed/screens/gallery_screen.dart';
import 'package:huear_fixed/screens/login_screen.dart';
import 'package:huear_fixed/screens/color_identification_camera_screen.dart'; // Your ColorIdentificationCameraScreen
import 'package:google_fonts/google_fonts.dart'; // For Inter font or other modern fonts

class HomeScreen extends StatefulWidget {
  // Removed startDirectlyToMain parameter.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _showMainHome = false; // Controls whether to show splash or main home
  int _selectedIndex = 0;

  final List<String> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    // _showMainHome always starts as false, so the splash screen is always shown initially.
    // Removed _checkLoginStatusAndLoadHome as it's no longer needed for initial state.
  }

  @override
  // ignore: unnecessary_overrides
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _handleNewImage(String imagePath) {
    setState(() {
      _capturedImages.insert(0, imagePath); // Add new image to the beginning
      // ignore: avoid_print
      print("HomeScreen - Captured image path: $imagePath");
      // If currently on the gallery tab, refresh it
      if (_selectedIndex == 1) {
        // This will trigger a rebuild of GalleryScreen with updated capturedImages
        // No explicit action needed here beyond setState, as GalleryScreen consumes _capturedImages
      }
    });
  }

  // Function to show the camera selection modal
  void _showCameraSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Make background transparent for rounded corners
      builder: (BuildContext bc) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), // Rounded top corners
          ),
          child: SafeArea(
            child: Wrap(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  child: Text(
                    'Choose Camera Mode',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xFF007AFF)),
                  title: Text(
                    'Object & Color Detection',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(bc); // Close the bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ARColorDetectorScreen(
                          onImageCaptured: _handleNewImage,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.color_lens, color: Color(0xFF2196F3)),
                  title: Text(
                    'Center Pixel Color Identification',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(bc); // Close the bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ColorIdentificationCameraScreen(
                          onImageCaptured: _handleNewImage,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16), // Add some bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  // Updated buildHomeContent to reflect UI suggestions
  Widget buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Your Recent Detections
          Text(
            "Your Recent Detections",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180, // Height for horizontal scroll view
            child: _capturedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text(
                          "No photos captured yet!",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
                        ),
                        Text(
                          "Tap the camera button to get started.",
                          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedImages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 12.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias, // Ensures content respects border radius
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Image.file(
                                  File(_capturedImages[index]),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Detection Result', // Placeholder for actual detection data
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 32),

          // Section: Explore Features
          Text(
            "Explore Features",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              // Object & Color Detection Card
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ARColorDetectorScreen(
                        onImageCaptured: _handleNewImage,
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt, size: 40, color: const Color(0xFF007AFF)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Object & Color Detection',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Identify objects and their colors in real-time.',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Center Pixel Color Identification Card
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ColorIdentificationCameraScreen(
                        onImageCaptured: _handleNewImage,
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.color_lens, size: 40, color: const Color(0xFF2196F3)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Center Pixel Color Identification',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Get precise color details from the center of your camera view.',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20), // Padding for bottom FAB
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showMainHome) {
      // Splash/Get Started Screen
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE0F7FA), Color(0xFFBBDEFB)], // Light blue gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // HueAR Logo
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hue',
                          style: GoogleFonts.gidugu( // Using GoogleFonts for Gidugu
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                        TextSpan(
                          text: 'AR',
                          style: GoogleFonts.gidugu( // Using GoogleFonts for Gidugu
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Engaging Visual - Placeholder for now
                  Icon(
                    Icons.color_lens_outlined, // Example icon
                    size: 120,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "Discover the world in a new light. Identify objects and their colors with HueAR.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    onPressed: () => setState(() => _showMainHome = true), // This button sets _showMainHome to true
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF), // Primary blue
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Main Home Screen
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Hue',
                style: GoogleFonts.gidugu(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF007AFF),
                ),
              ),
              TextSpan(
                text: 'AR',
                style: GoogleFonts.gidugu(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2, // Subtle shadow for AppBar
        actions: [
          Builder( // Use Builder to get a context that can find the Scaffold
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openEndDrawer(), // Open the end drawer
            ),
          ),
        ],
      ),
      endDrawer: Drawer( // Replaced AnimatedPositioned with Drawer
        child: ListView(
          padding: EdgeInsets.zero, // Remove default padding
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                gradient: LinearGradient(
                  colors: [const Color(0xFF007AFF), Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hue',
                          style: GoogleFonts.gidugu(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'AR',
                          style: GoogleFonts.gidugu(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Color Assistant',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.grey[700]),
              title: Text(
                'Profile',
                style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            const Divider(), // Add a divider for separation
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                'Logout',
                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 16),
              ),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                await _logout();
              },
            ),
          ],
        ),
      ),
      body: _selectedIndex == 0
          ? buildHomeContent()
          : GalleryScreen(
              capturedImages: _capturedImages,
              onImageDeleted: (index) {
                setState(() {
                  _capturedImages.removeAt(index);
                });
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCameraSelectionSheet, // Call the new selection method
        backgroundColor: const Color(0xFF007AFF), // Primary blue
        elevation: 4, // More prominent shadow
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Rounded square shape
        child: const Icon(Icons.camera_alt, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8, // Subtle shadow for BottomAppBar
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: InkWell( // Use InkWell for better tap feedback
                  onTap: () => _onItemTapped(0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.home,
                        color: _selectedIndex == 0
                            ? const Color(0xFF007AFF) // Active color
                            : Colors.grey[400],
                        size: 30,
                      ),
                      Text(
                        'Home',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _selectedIndex == 0
                              ? const Color(0xFF007AFF)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 48), // Space for FAB
              Expanded(
                child: InkWell( // Use InkWell for better tap feedback
                  onTap: () => _onItemTapped(1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: _selectedIndex == 1
                            ? const Color(0xFF007AFF) // Active color
                            : Colors.grey[400],
                        size: 30,
                      ),
                      Text(
                        'Gallery',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _selectedIndex == 1
                              ? const Color(0xFF007AFF)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
