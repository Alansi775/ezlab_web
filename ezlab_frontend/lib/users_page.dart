// lib/users_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; 
// تأكد من وجود ملف constants.dart في الجذر
import 'package:ezlab_frontend/constants.dart'; 
import 'widgets/sidebar.dart'; 

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _searchQuery = '';
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _loggedInUserRole = 'user';
  String _loggedInUsername = '';

  // تعريف مستخدم السوبر أدمن لضمان حمايته
  static const String _SUPER_ADMIN_USERNAME = 'superadmin_ezlab'; 

  // الألوان المستخدمة من ملف constants.dart
  final Color _backgroundColor = AppColors.background;
  final Color _cardColor = AppColors.cardBackground;
  final Color _switchActiveColor = AppColors.primaryDark;
  final Color _switchInactiveColor = AppColors.textSecondary.withOpacity(0.5);

  @override
  void initState() {
    super.initState();
    _loadCurrentUserDetails().then((_) {
      if (_loggedInUserRole == 'admin' || _loggedInUserRole == 'super_admin') {
        _fetchUsers();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadCurrentUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _loggedInUserRole = prefs.getString('role') ?? 'user';
      _loggedInUsername = prefs.getString('username') ?? '';
    });
  }

  Future<void> _fetchUsers() async {
    if (_loggedInUserRole != 'admin' && _loggedInUserRole != 'super_admin') return;

    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          // فرز المستخدمين: سوبر أدمن، ثم مدراء، ثم مستخدمين عاديين
          _users = (json.decode(response.body) as List<dynamic>).map((user) => user as Map<String, dynamic>).toList();
          _users.sort((a, b) {
            final roleA = a['role'] as String? ?? 'user';
            final roleB = b['role'] as String? ?? 'user';
            
            if (roleA == 'super_admin') return -1;
            if (roleB == 'super_admin') return 1;
            if (roleA == 'admin' && roleB == 'user') return -1;
            if (roleA == 'user' && roleB == 'admin') return 1;
            return a['username'].compareTo(b['username']);
          });
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to fetch users: ${response.body}', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error fetching users: $e', isError: true);
    }
  }

  // دالة الفلترة بناءً على حقل البحث
  List<dynamic> _getFilteredUsers() {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    final lowerCaseQuery = _searchQuery.toLowerCase();
    return _users.where((user) {
      final username = user['username']?.toLowerCase() ?? '';
      return username.contains(lowerCaseQuery);
    }).toList();
  }

  Future<void> _updateUserStatus(String userId, bool isActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$userId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({'value': isActive ? 1 : 0}),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
        _showSnackBar('User status updated successfully.');
      } else {
        final resBody = json.decode(response.body);
        _showSnackBar(resBody['message'] ?? 'Failed to update user status', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating user status: $e', isError: true);
    }
  }

  Future<void> _updateUserRole(String userId, bool isAdmin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$userId/role'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({'value': isAdmin ? 'admin' : 'user'}),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
        _showSnackBar('User role updated successfully.');
      } else {
        final resBody = json.decode(response.body);
        _showSnackBar(resBody['message'] ?? 'Failed to update user role', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating user role: $e', isError: true);
    }
  }

  Future<void> _deleteUser(String userId, String usernameToDelete) async {
    if (usernameToDelete == _SUPER_ADMIN_USERNAME) {
      _showSnackBar('Cannot delete the Super Admin user.', isError: true);
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Deletion', style: GoogleFonts.lato(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete user $usernameToDelete?', style: GoogleFonts.lato(color: AppColors.textSecondary)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.textPrimary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';

        final response = await http.delete(
          Uri.parse('$baseUrl/api/users/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
        );
        if (response.statusCode == 200) {
          _fetchUsers();
          _showSnackBar('User deleted successfully');
        } else {
          final resBody = json.decode(response.body);
          _showSnackBar(resBody['message'] ?? 'Failed to delete user', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error deleting user: $e', isError: true);
      }
    }
  }

  // مربع حوار إضافة مستخدم جديد (الدور الافتراضي هو 'user')
  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New User', style: GoogleFonts.lato(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(controller: usernameController, label: 'Username'),
            const SizedBox(height: 16),
            _buildTextField(controller: passwordController, label: 'Password'),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary), child: Text('Cancel', style: GoogleFonts.lato())),
          ElevatedButton(
            // تعيين الدور بشكل ثابت إلى 'user'
            onPressed: () => _handleRegisterUser(usernameController.text, passwordController.text, 'user'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Add User', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegisterUser(String username, String password, String role) async {
    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Username and Password are required.', isError: true);
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'username': username,
          'password': password,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        if(mounted) Navigator.pop(context); 
        _showSnackBar('User added successfully');
        _fetchUsers(); 
      } else {
        String errorMessage = 'Failed to add user';
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {}
        }
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error adding user: $e', isError: true);
    }
  }

  // حقل إدخال قياسي
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    // نستخدم Theme لتطبيق لون التظليل بشكل صحيح لـ TextFormField داخل الـ Dialog
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.primary.withOpacity(0.3),
          selectionHandleColor: AppColors.primary,
        ),
      ),
      child: TextFormField(
        controller: controller,
        cursorColor: AppColors.primary, // لون المؤشر
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.lato(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.lato(color: AppColors.textPrimary),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
          backgroundColor: isError ? AppColors.danger : AppColors.primary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool canManageUsers = _loggedInUserRole == 'admin' || _loggedInUserRole == 'super_admin';
    
    if (!canManageUsers && !_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'ACCESS DENIED: You do not have the required permissions to manage users.',
            style: TextStyle(color: AppColors.danger, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final List<dynamic> filteredUsers = _getFilteredUsers();
    final List<dynamic> adminUsers = filteredUsers.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin').toList();
    final List<dynamic> regularUsers = filteredUsers.where((u) => u['role'] == 'user').toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Row(
        children: [
          // 1. الشريط الجانبي (Sidebar)
          AppSidebar(
            activePage: 'Users',
            userName: _loggedInUsername,
            userRole: _loggedInUserRole,
            onAddUser: canManageUsers ? _showAddUserDialog : null,
          ),

          // 2. منطقة المحتوى الرئيسية
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الرأس وشريط البحث
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Manage System Users',
                          style: GoogleFonts.lato(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                          ),
                        ),
                      ),
                      // حقل البحث (Search Bar) - تم تضمينه في ويدجت Theme لتطبيق ألوان التظليل
                      SizedBox(
                        width: 300, 
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: TextSelectionThemeData(
                              cursorColor: AppColors.primary,
                              selectionColor: AppColors.primary.withOpacity(0.3), // لون التظليل
                              selectionHandleColor: AppColors.primary, // لون مقابض التحديد
                            ),
                          ),
                          child: TextFormField(
                            // لون المؤشر
                            cursorColor: AppColors.primary, 
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search by username...',
                              hintStyle: GoogleFonts.lato(color: AppColors.textSecondary.withOpacity(0.7)),
                              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                              filled: true,
                              fillColor: AppColors.cardBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              // لون الحدود عند التركيز
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2), 
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            style: GoogleFonts.lato(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // قائمة المستخدمين
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : RefreshIndicator(
                    onRefresh: _fetchUsers,
                    color: AppColors.primary,
                    backgroundColor: AppColors.background,
                    child: filteredUsers.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No users found matching "$_searchQuery".' : 'No users found.',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: Text('Show all users', style: GoogleFonts.lato(color: AppColors.primary)),
                            ),
                        ],
                      ),
                    )
                        : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                      children: [
                        // --- قسم المدراء (Admins & Super Admins) ---
                        if (adminUsers.isNotEmpty) ...[
                          _buildSectionHeader('System Administrators (${adminUsers.length})', Icons.security_rounded, AppColors.accent),
                          const SizedBox(height: 12),
                          ...adminUsers.map((user) => _buildUserCard(user, isCurrent: user['username'] == _loggedInUsername)).toList(),
                          const SizedBox(height: 30),
                        ],
                        
                        // --- قسم المستخدمين العاديين (Regular Users) ---
                        if (regularUsers.isNotEmpty) ...[
                          _buildSectionHeader('Regular Users (${regularUsers.length})', Icons.group_rounded, AppColors.primary),
                          const SizedBox(height: 12),
                          ...regularUsers.map((user) => _buildUserCard(user, isCurrent: user['username'] == _loggedInUsername)).toList(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت عنوان القسم
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0), 
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.lato(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Divider(thickness: 1, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت بطاقة المستخدم
  Widget _buildUserCard(Map<String, dynamic> user, {required bool isCurrent}) {
    final String currentUsername = user['username'] ?? '';
    final String currentRole = user['role'] ?? 'user';
    final String userId = user['id'].toString();
    final bool isSuperAdmin = currentUsername == _SUPER_ADMIN_USERNAME;

    // تحديد صلاحيات التعديل والحذف
    final bool canModifyThisUser = (_loggedInUserRole == 'super_admin' && !isSuperAdmin) ||
        (_loggedInUserRole == 'admin' && currentRole != 'super_admin' && currentUsername != _loggedInUsername);
    
    final bool canDeleteThisUser = canModifyThisUser && !isSuperAdmin;

    return Card(
      // تظليل المستخدم الحالي
      color: isCurrent ? AppColors.primary.withOpacity(0.1) : _cardColor, 
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSuperAdmin ? const BorderSide(color: AppColors.accent, width: 2) : (isCurrent ? const BorderSide(color: AppColors.primary, width: 2) : BorderSide.none),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isSuperAdmin ? AppColors.accent : (currentRole == 'admin' ? AppColors.primary : AppColors.textSecondary.withOpacity(0.7)),
                  child: Text(
                    currentUsername.isNotEmpty ? currentUsername[0].toUpperCase() : 'U',
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUsername,
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            isSuperAdmin ? 'SUPER ADMIN' : currentRole.toUpperCase(),
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSuperAdmin ? AppColors.accent : (currentRole == 'admin' ? AppColors.primary : AppColors.textSecondary),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Text(' (You)', style: GoogleFonts.lato(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                if (canDeleteThisUser)
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 28),
                    onPressed: () => _deleteUser(userId, currentUsername),
                    tooltip: 'Delete User',
                  ),
                if (isSuperAdmin)
                   Tooltip(
                    message: 'Cannot modify or delete the Super Admin.',
                    child: Icon(Icons.lock_rounded, color: AppColors.accent, size: 24),
                  ),
              ],
            ),
            const Divider(height: 30, thickness: 1, color: AppColors.background),
            
            // عناصر التحكم (Controls)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSwitchControl(
                  label: 'Admin Privileges',
                  value: currentRole == 'admin' || currentRole == 'super_admin',
                  onChanged: canModifyThisUser && !isSuperAdmin 
                      ? (v) => _updateUserRole(userId, v)
                      : null, 
                  isSuperAdmin: isSuperAdmin,
                ),
                _buildSwitchControl(
                  label: 'Account Active',
                  value: user['isActive'] == 1,
                  onChanged: canModifyThisUser && !isSuperAdmin
                      ? (v) => _updateUserStatus(userId, v)
                      : null, 
                  isSuperAdmin: isSuperAdmin,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت مفتاح التبديل (Switch Control)
  Widget _buildSwitchControl({
    required String label,
    required bool value,
    required Function(bool)? onChanged,
    bool isSuperAdmin = false,
  }) {
    final bool isDisabled = onChanged == null;

    return Expanded(
      child: Tooltip(
        message: isDisabled ? (isSuperAdmin ? 'Cannot modify Super Admin' : 'Cannot modify your own account') : label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.lato(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: _switchActiveColor,
                activeTrackColor: _switchActiveColor.withOpacity(0.4),
                inactiveThumbColor: isDisabled ? Colors.grey[400] : _switchInactiveColor,
                inactiveTrackColor: isDisabled ? Colors.grey[200] : _switchInactiveColor.withOpacity(0.4),
                thumbIcon: isDisabled 
                  ? MaterialStateProperty.all(const Icon(Icons.lock, size: 16, color: Colors.white)) 
                  : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}