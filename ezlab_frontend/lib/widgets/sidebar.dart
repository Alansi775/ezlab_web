// lib/widgets/sidebar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../product_page.dart';
import '../customer_orders_page.dart';
import '../users_page.dart';
import '../login.dart';

// ⚠️ (ملاحظة: يجب التأكد من وجود دالة _showAddUserDialog في صفحة UsersPage أو إنشاءها في مكان مركزي إذا لزم الأمر.)

class AppSidebar extends StatefulWidget {
  final String activePage;
  final String userName;
  final String userRole;
  final VoidCallback? onAddUser; // لـ Add User dialog
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
    // مدة قصيرة للانتقال (مثل 300 مللي ثانية)
    transitionDuration: const Duration(milliseconds: 150), 
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // استخدام FadeTransition لتطبيق تأثير التلاشي
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}


  // 1. الدالة المساعدة لبناء كل عنصر في الشريط الجانبي
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
              Text(
                title,
                style: GoogleFonts.lato(
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. دالة تسجيل الخروج
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
        _fadePageRoute(LoginPage()), // استدعاء الدالة الجديدة
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
          // 3. ✨ NEW: Logo Area
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

          // 4. ✨ NEW: User Profile Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.8),
                  child: Text(
                    // ⭐ التحصين الأول: استخدام 'U' كقيمة افتراضية بدلاً من محاولة الوصول إلى الحرف الأول من سلسلة فارغة أو null
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U', 
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // ⭐ التحصين الثاني: استخدام 'Guest' إذا كانت القيمة فارغة
                  widget.userName.isNotEmpty ? widget.userName : 'Guest', 
                  style: GoogleFonts.lato(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  // ⭐ التحصين الثالث: استخدام 'USER' إذا كانت القيمة فارغة
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
                  title: 'Products',
                  onTap: () {
                    if (widget.activePage == 'Products' && widget.isDetailPage) {
                      // إذا كنا في صفحة تفاصيل المنتج، نعود للخلف (pop)
                      Navigator.pop(context);
                    } else if (widget.activePage != 'Products') {
                      // إذا لم نكن في الصفحة، ننتقل إليها (pushReplacement)
                      Navigator.pushReplacement(context, _fadePageRoute(const ProductPage()));
                    }
                  },
                  isActive: widget.activePage == 'Products',
                ),

                // Customer Orders (Using Sales Pipeline Icon)
                _buildSidebarTile(
                  icon: Icons.receipt_long,
                  title: 'Customer Orders',
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
                    child: Text('Admin Tools', style: GoogleFonts.lato(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  // Manage Users Link
                  _buildSidebarTile(
                    icon: Icons.people_alt_rounded,
                    title: 'Manage Users',
                    onTap: () {
                      if (widget.activePage != 'Users') {
                        Navigator.push(context, _fadePageRoute(const UsersPage()));
                      }
                    },
                    isActive: widget.activePage == 'Users',
                  ),
                  // Add User Link (New requirement: direct link from sidebar)
                  if (widget.onAddUser != null)
                    _buildSidebarTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Add User',
                      onTap: widget.onAddUser!,
                    ),
                ],

                // Logout
                Padding(
                  padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
                  child: _buildSidebarTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
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