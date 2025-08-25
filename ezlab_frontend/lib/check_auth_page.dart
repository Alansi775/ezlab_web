// lib/check_auth_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezlab_frontend/login.dart';
import 'package:ezlab_frontend/product_page.dart';
import 'package:ezlab_frontend/SplashScreen.dart'; // Import the new splash screen
import 'package:ezlab_frontend/constants.dart';

class CheckAuthPage extends StatefulWidget {
  const CheckAuthPage({Key? key}) : super(key: key);

  @override
  _CheckAuthPageState createState() => _CheckAuthPageState();
}

class _CheckAuthPageState extends State<CheckAuthPage> {
  // متغير لتحديد هل المستخدم مسجل دخوله أم لا
  bool _isLoggedIn = false;
  // متغير لتحديد ما إذا كنا قد انتهينا من التحقق
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final role = prefs.getString('role');

    // إذا كان الـ Token و Role موجودين، إذن المستخدم مسجل دخوله
    if (token != null && role != null) {
      if (mounted) {
        // انتقل فورًا إلى صفحة المنتجات
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ProductPage(userRole: role),
          ),
        );
      }
    } else {
      // إذا لم يكن مسجل دخوله، ابدأ حركة شاشة البداية
      setState(() {
        _isLoggedIn = false;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // أثناء التحقق الأولي، اعرض مؤشر تحميل سريع. هذا يحدث فقط للحظة قصيرة جداً
      // ولن يراه المستخدم عادة.
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      // إذا لم يكن المستخدم مسجل دخوله، اعرض شاشة البداية الأنيقة
      // وعند اكتمال حركتها، انتقل إلى صفحة تسجيل الدخول
      return const SplashScreen();
    }
  }
}