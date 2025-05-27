import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'camera_screen.dart';
import 'gallery_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _showMainHome = false;
  int _selectedIndex = 0; // Home selected by default
  bool _menuVisible = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _toggleMenu() {
    setState(() {
      _menuVisible = !_menuVisible;
      _menuVisible
          ? _animationController.forward()
          : _animationController.reverse();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  Widget buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/result-pop-up-img.png',
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Finally, know what color truly looks like.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6E6E6E),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(1.0, -1.0),
              child: Image.asset(
                'assets/result-pop-up-img.png',
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showMainHome) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Hue',
                        style: TextStyle(
                          fontFamily: 'Gidugu',
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      TextSpan(
                        text: 'AR',
                        style: TextStyle(
                          fontFamily: 'Gidugu',
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => setState(() => _showMainHome = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                  ),
                  child: const Text('Get Started'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Hue',
                style: TextStyle(
                  fontFamily: 'Gidugu',
                  fontSize: 24,
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' AR',
                style: TextStyle(
                  fontFamily: 'Gidugu',
                  fontSize: 24,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: _toggleMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_selectedIndex == 0)
            buildHomeContent()
          else if (_selectedIndex == 1)
            const GalleryScreen()
          else if (_selectedIndex == 2)
            const ProfileScreen(),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: _menuVisible ? 0 : -300,
            top: 0,
            bottom: 0,
            child: Container(
              width: 300,
              color: Colors.grey[100],
              child: ListView(
                padding: const EdgeInsets.only(top: 50, left: 20),
                children: [
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.grey[700]),
                    title: Text(
                      'Profile',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    onTap: () {
                      _toggleMenu();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () async {
                      _toggleMenu();
                      await _logout();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          );
        },
        backgroundColor: const Color(0xFF2196F3),
        elevation: 2,
        child: const Icon(Icons.camera_alt, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: _selectedIndex == 0
                      ? const Color(0xFF2196F3)
                      : Colors.grey[400],
                  size: 32,
                ),
                onPressed: () => _onItemTapped(0),
              ),
              const SizedBox(width: 32), // Space for FAB
              // Gallery
              IconButton(
                icon: Icon(
                  Icons.photo_library,
                  color: _selectedIndex == 1
                      ? const Color(0xFF2196F3)
                      : Colors.grey[400],
                  size: 32,
                ),
                onPressed: () => _onItemTapped(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}