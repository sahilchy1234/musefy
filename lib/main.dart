import 'package:flutter/material.dart';
import 'pages/authentication/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusefyApp());
}

class MusefyApp extends StatelessWidget {
  const MusefyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Musefy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFF121212),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
