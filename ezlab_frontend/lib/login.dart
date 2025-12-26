// ezlab_frontend/lib/login.dart
import 'package:ezlab_frontend/product_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezlab_frontend/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ezlab_frontend/providers/language_provider.dart';
import 'package:ezlab_frontend/services/language_service.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  final _formKey = GlobalKey<FormState>();

  PageRouteBuilder _fadePageRoute(Widget targetPage) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => targetPage,
      transitionDuration: const Duration(milliseconds: 300), 
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final resBody = json.decode(response.body);
        final role = resBody['user']['role'];
        final username = resBody['user']['username'];
        final token = resBody['token'];
        final userId = resBody['user']['id'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('role', role);
        await prefs.setString('username', username);
        await prefs.setInt('user_id', userId);

        Navigator.pushReplacement(
          context,
          _fadePageRoute(
            ProductPage(userRole: role),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid credentials. Please try again.';
          if (response.body.isNotEmpty) {
            try {
              final errorData = json.decode(response.body);
              _errorMessage = errorData['message'] ?? _errorMessage;
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        print('Login error: $e');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE0F2F7),
                  Color(0xFFBBC1C6),
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(32),
                      width: 400,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: -5,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            //  NBK CRM مع Directionality للمفتاح
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.vpn_key_rounded, size: 40, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    'NBK',
                                    style: GoogleFonts.lato(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900, 
                                      color: AppColors.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    ' CRM',
                                    style: GoogleFonts.lato(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w300,
                                      color: AppColors.textSecondary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              languageProvider.getString('sign_in_to_command'),
                              style: _getTextStyle(
                                languageProvider.isRTL,
                                fontSize: 16,
                              ).copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 32),

                            Theme(
                              data: Theme.of(context).copyWith(
                                textSelectionTheme: TextSelectionThemeData(
                                  cursorColor: AppColors.primary,
                                  selectionColor: AppColors.primary.withOpacity(0.3),
                                  selectionHandleColor: AppColors.primary,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTextField(
                                    controller: _usernameController,
                                    label: languageProvider.getString('username'),
                                    icon: Icons.person_outline_rounded,
                                    validator: (value) => value!.isEmpty ? languageProvider.getString('username') : null,
                                    onSubmitted: () {
                                      FocusScope.of(context).nextFocus();
                                    },
                                    isRTL: languageProvider.isRTL,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: languageProvider.getString('password'),
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: AppColors.textSecondary.withOpacity(0.7),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    validator: (value) => value!.isEmpty ? languageProvider.getString('password') : null,
                                    onSubmitted: _login,
                                    isRTL: languageProvider.isRTL,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                            if (_errorMessage.isNotEmpty)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.danger.withOpacity(0.5)),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            _LoginButton(
                              isLoading: _isLoading,
                              onPressed: _login,
                              languageProvider: languageProvider,
                            ),
                            const SizedBox(height: 24),
                            _buildLanguageSelector(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // THIS FUNCTION RETURNS TEXT STYLE BASED ON LANGUAGE DIRECTION
  TextStyle _getTextStyle(bool isRTL, {double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    if (isRTL) {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
      );
    }
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    VoidCallback? onSubmitted,
    bool isRTL = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: (value) {
        if (onSubmitted != null) {
          onSubmitted();
        }
      },
      style: _getTextStyle(isRTL, fontSize: 16),
      cursorColor: AppColors.primary.withOpacity(0.7), 
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _getTextStyle(isRTL).copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7)),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final languages = [
          ('en', 'English', 'EN'),
          ('ar', 'العربية', 'AR'),
          ('tr', 'Türkçe', 'TR'),
        ];

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: languages.map((lang) {
              final isSelected = languageProvider.currentLanguage == lang.$1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ElevatedButton(
                  onPressed: () async {
                    await languageProvider.setLanguage(lang.$1);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.primary : Colors.white,
                    foregroundColor: isSelected ? Colors.white : AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary,
                      width: isSelected ? 0 : 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: isSelected ? 4 : 0,
                  ),
                  child: Text(
                    lang.$3,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final LanguageProvider languageProvider;

  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
    required this.languageProvider,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isLoading) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isLoading) {
      _animationController.reverse();
    }
  }

  void _onTapCancel() {
    if (!widget.isLoading) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 56, 
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16), 
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.7),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
            height: 28, 
            width: 28,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3, 
            ),
          )
              : Text(
            widget.languageProvider.getString('sign_in'),
            style: (widget.languageProvider.isRTL
                ? GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  )
                : GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  )),
          ),
        ),
      ),
    );
  }
}
