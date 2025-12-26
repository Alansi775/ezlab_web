// ezlab_frontend/lib/widgets/sidebar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../product_page.dart';
import '../customer_orders_page.dart';
import '../users_page.dart';
import '../login.dart';
import '../language_settings_page.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AppSidebar extends StatefulWidget {
  final String activePage;
  final String userName;
  final String userRole;
  final VoidCallback? onAddUser; // For Add User dialog
  final bool isDetailPage;

  const AppSidebar({
    Key? key,
    required this.activePage,
    required this.userName,
    required this.userRole,
    this.onAddUser,
    this.isDetailPage = false,
  }) : super(key: key);

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {

  PageRouteBuilder _fadePageRoute(Widget targetPage) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => targetPage,
    // Short duration for transition (e.g., 150 milliseconds)
    transitionDuration: const Duration(milliseconds: 150), 
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Use FadeTransition to apply fade effect
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

  // Function to get the appropriate font style based on language direction
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


  // 1. Helper function to build each item in the sidebar
  Widget _buildSidebarTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.textPrimary.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _getTextStyle(
                    context.read<LanguageProvider>().isRTL,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Logout function
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    await prefs.clear();

    if (token != null) {
      try {
        // Assume baseUrl is accessible or passed/defined globally
        await http.post(Uri.parse('$baseUrl/auth/logout'), headers: {'Authorization': 'Bearer $token'});
      } catch (e) {
        print('Logout error: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        _fadePageRoute(LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageUsers = widget.userRole == 'admin' || widget.userRole == 'super_admin';

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // 3. NEW: Logo Area
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NBK',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                Text(
                  ' CRM',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.background),

          // 4. NEW: User Profile Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.8),
                  child: Text(
                    // First safeguard: Use 'U' as a default value instead of trying to access the first character of an empty or null string
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U', 
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // Second safeguard: Use 'Guest' if the value is empty
                  widget.userName.isNotEmpty ? widget.userName : 'Guest', 
                  style: GoogleFonts.lato(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  // Third safeguard: Use 'USER' if the value is empty
                  (widget.userRole.isNotEmpty ? widget.userRole : 'user').toUpperCase(), 
                  style: GoogleFonts.lato(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.background),

          // 5. Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                // Dashboard / Products (Active in ProductPage)
                _buildSidebarTile(
                  icon: Icons.inventory_2_rounded,
                  title: context.read<LanguageProvider>().getString('products'),
                  onTap: () {
                    if (widget.activePage == 'Products' && widget.isDetailPage) {
                      Navigator.pop(context);
                    } else if (widget.activePage != 'Products') {
                      Navigator.pushReplacement(context, _fadePageRoute(const ProductPage()));
                    }
                  },
                  isActive: widget.activePage == 'Products',
                ),

                // Customer Orders (Using Sales Pipeline Icon)
                _buildSidebarTile(
                  icon: Icons.receipt_long,
                  title: context.read<LanguageProvider>().getString('customer_orders'),
                  onTap: () {
                    if (widget.activePage != 'Orders') {
                      Navigator.pushReplacement(context, _fadePageRoute(const CustomerOrdersPage()));
                    }
                  },
                  isActive: widget.activePage == 'Orders',
                ),

                // Admin Tools Section
                if (canManageUsers) ...[
                  const Divider(height: 20, color: AppColors.background, indent: 15, endIndent: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(
                      context.read<LanguageProvider>().getString('admin_tools'),
                      style: _getTextStyle(
                        context.read<LanguageProvider>().isRTL,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary.withOpacity(0.6),
                      ),
                    ),
                  ),
                  // Manage Users Link
                  _buildSidebarTile(
                    icon: Icons.people_alt_rounded,
                    title: context.read<LanguageProvider>().getString('manage_users'),
                    onTap: () {
                      if (widget.activePage != 'Users') {
                        Navigator.push(context, _fadePageRoute(const UsersPage()));
                      }
                    },
                    isActive: widget.activePage == 'Users',
                  ),
                  // Add User Link
                  if (widget.onAddUser != null)
                    _buildSidebarTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: context.read<LanguageProvider>().getString('add_user'),
                      onTap: widget.onAddUser!,
                    ),
                ],

                // Settings (New)
                const Divider(height: 20, color: AppColors.background, indent: 15, endIndent: 15),
                _buildSidebarTile(
                  icon: Icons.settings_rounded,
                  title: context.read<LanguageProvider>().getString('settings'),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const LanguageSettingsPage(),
                        transitionDuration: const Duration(milliseconds: 150),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),

                // Logout
                Padding(
                  padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
                  child: _buildSidebarTile(
                    icon: Icons.logout_rounded,
                    title: context.read<LanguageProvider>().getString('logout'),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}