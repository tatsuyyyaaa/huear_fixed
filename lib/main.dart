import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Check login state before running the app
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HueAR',
      debugShowCheckedModeBanner: false, // Hide the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // If logged in, go to HomeScreen (which will show the splash first).
      // Otherwise, go to the LoginScreen.
      home: isLoggedIn
          ? const HomeScreen() // Removed 'startDirectlyToMain: true'
          : const LoginScreen(),
      routes: {
        // Note: '/login' and '/home' are primarily handled by the 'home' property for initial app launch.
        // However, defining them here still allows for named navigation if needed from other parts of the app
        // (e.g., Navigator.pushNamed(context, '/register')).
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(), // Ensure this also creates HomeScreen without the flag
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}
