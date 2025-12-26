// lib/main.dart
import 'package:flutter/material.dart';
import 'package:ezlab_frontend/check_auth_page.dart'; 
import 'package:ezlab_frontend/login.dart';
import 'package:ezlab_frontend/product_page.dart';
import 'package:ezlab_frontend/SplashScreen.dart'; 
import 'package:provider/provider.dart';
import 'package:ezlab_frontend/providers/language_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            title: 'NBK CRM',
            debugShowCheckedModeBanner: false,
            locale: languageProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
              Locale('tr'),
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: languageProvider.textDirection,
                child: child!,
              );
            },
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
        },
      ),
    );
  }
}