// lib/main.dart
import 'package:flutter/material.dart';
import 'package:ezlab_frontend/check_auth_page.dart'; 
import 'package:ezlab_frontend/login.dart';
import 'package:ezlab_frontend/product_page.dart';
import 'package:ezlab_frontend/SplashScreen.dart'; 

import 'constants.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezlab CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary.withOpacity(0.7),
        hintColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: AppColors.textPrimary),
          headlineMedium: TextStyle(color: AppColors.textPrimary),
        ),
        useMaterial3: true,
      ),
      home: const CheckAuthPage(), // THE APP STARTS HERE
      routes: {
        '/login': (context) => LoginPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/products') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ProductPage(userRole: args['role']),
          );
        }
        return null;
      },
    );
  }
}