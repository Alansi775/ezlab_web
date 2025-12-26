// lib/SplashScreen.dart (الكود الكامل المُعدّل)

import 'package:flutter/material.dart';
import 'package:ezlab_frontend/login.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ezlab_frontend/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _crmOpacityAnimation; //  جديد: لـ CRM

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), 
    );

    // حركة الأيقونة: تظهر وتكبر بسلاسة (من 0.5 إلى 1.0)
    _iconScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // حركة النص (NBK): يظهر تدريجيًا بعد الأيقونة
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    // حركة النص (CRM): يظهر متأخراً قليلاً
    _crmOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // تأثير التوهج: يظهر تدريجيًا ويختفي (أكثر سلاسة)
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );


    _controller.forward();

    // الانتقال بعد انتهاء الحركة
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // استخدام تدرج لوني أكثر اتساقًا مع هوية NBK
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F2F7), // لون فاتح
              Color(0xFFFFFFFF), // لون سماوي
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الأيقونة مع تأثير التوهج والحركة
                  Transform.scale(
                    scale: _iconScaleAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // تأثير التوهج
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5 * _glowAnimation.value),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        // الأيقونة نفسها
                        Icon(
                          Icons.radar_rounded, // أيقونة احترافية
                          size: 100,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  //  التعديل هنا: اسم الشركة NBK CRM
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // NBK
                      Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Text(
                          'NBK',
                          style: GoogleFonts.lato(
                            fontSize: 65,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 4,
                            shadows: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // CRM
                      Opacity(
                        opacity: _crmOpacityAnimation.value,
                        child: Text(
                          ' CRM',
                          style: GoogleFonts.lato(
                            fontSize: 55, // أصغر قليلاً من NBK
                            fontWeight: FontWeight.w300,
                            color: AppColors.textSecondary,
                            letterSpacing: 4,
                            shadows: [
                              BoxShadow(
                                color: AppColors.textSecondary.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}