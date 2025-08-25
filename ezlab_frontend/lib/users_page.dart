// lib/users_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezlab_frontend/constants.dart'; // Corrected import to utils/constants.dart

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _loggedInUserRole = 'user'; // Store the logged-in user's role
  String _loggedInUsername = ''; // Store the logged-in user's username

  // Define the Super Admin username constant here as well
  // This MUST match the SUPER_ADMIN_USERNAME in userController.js
  static const String _SUPER_ADMIN_USERNAME = 'superadmin_ezlab'; // <--- IMPORTANT: Match backend!

  // Using AppColors from constants.dart for consistency
  final Color _backgroundColor = AppColors.background;
  final Color _primaryColor = AppColors.primary.withOpacity(0.7);
  final Color _cardColor = AppColors.cardBackground;
  final Color _switchActiveColor = AppColors.primaryDark;
  final Color _switchInactiveColor = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserDetails().then((_) {
      _fetchUsers();
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
          _users = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch users: ${response.body}')), // Show backend message
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e')),
        );
      }
    }
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
      } else {
        if (mounted) {
          final resBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resBody['message'] ?? 'Failed to update user status')),
          );
        }
      }
    } catch (e) {
      print('Error updating user status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user status: $e')),
        );
      }
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
      } else {
        if (mounted) {
          final resBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resBody['message'] ?? 'Failed to update user role')),
          );
        }
      }
    } catch (e) {
      print('Error updating user role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user role: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String usernameToDelete) async {
    // Prevent Super Admin from deleting themselves or others
    if (usernameToDelete == _SUPER_ADMIN_USERNAME) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the Super Admin user.')),
      );
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete user $usernameToDelete?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')),
            );
          }
        } else {
          if (mounted) {
            final resBody = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(resBody['message'] ?? 'Failed to delete user')),
            );
          }
        }
      } catch (e) {
        print('Error deleting user: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show user management if logged-in user is admin or super_admin
    final bool canManageUsers = _loggedInUserRole == 'admin' || _loggedInUserRole == 'super_admin';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Manage Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchUsers,
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        child: _users.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_off_rounded, size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'No users found.',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final String currentUsername = user['username'] ?? '';
            final String currentRole = user['role'] ?? 'user';
            final bool isCurrentUserSuperAdmin = currentUsername == _SUPER_ADMIN_USERNAME;

            // Determine if the current logged-in user can manage this specific user
            // Super Admin can manage all except themselves (their own role/status)
            // Admin can manage all except Super Admin
            final bool canModifyThisUser = canManageUsers &&
                (currentUsername != _loggedInUsername) && // Cannot modify own status/role
                !isCurrentUserSuperAdmin; // Cannot modify super admin

            // The Super Admin (logged in) can delete other users, but cannot delete themselves.
            // A regular Admin can delete users, but not the Super Admin.
            final bool canDeleteThisUser = canManageUsers &&
                (currentUsername != _loggedInUsername) && // Cannot delete self
                !isCurrentUserSuperAdmin; // Cannot delete Super Admin

            return Card(
              color: _cardColor,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentUsername,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (canDeleteThisUser) // Only show delete button if allowed
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded,
                                color: AppColors.danger, size: 24),
                            onPressed: () => _deleteUser(
                                user['id'].toString(), currentUsername),
                            tooltip: 'Delete User',
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatusText('Role', currentRole.toUpperCase()),
                        const SizedBox(width: 24),
                        _buildStatusText(
                          'Status',
                          user['isActive'] == 1
                              ? 'Active'
                              : 'Blocked',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSwitchControl(
                          label: 'Admin Privileges',
                          value: currentRole == 'admin' || currentRole == 'super_admin', // Admin or Super Admin
                          onChanged: canModifyThisUser && currentRole != 'super_admin' // Disable if Super Admin, or if current user cannot modify
                              ? (v) => _updateUserRole(user['id'].toString(), v)
                              : null, // Disable the switch
                          isSuperAdmin: currentRole == 'super_admin',
                        ),
                        const SizedBox(width: 30),
                        _buildSwitchControl(
                          label: 'Account Active',
                          value: user['isActive'] == 1,
                          onChanged: canModifyThisUser && currentRole != 'super_admin' // Disable if Super Admin, or if current user cannot modify
                              ? (v) => _updateUserStatus(user['id'].toString(), v)
                              : null, // Disable the switch
                          isSuperAdmin: currentRole == 'super_admin',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusText(String label, String value) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Modified _buildSwitchControl to disable for Super Admin
  Widget _buildSwitchControl({
    required String label,
    required bool value,
    required Function(bool)? onChanged, // Can be null now
    bool isSuperAdmin = false, // New parameter
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Transform.scale(
          scale: 0.9,
          child: Switch(
            value: value,
            onChanged: onChanged, // Will be null if disabled
            activeColor: _switchActiveColor,
            activeTrackColor: _switchActiveColor.withOpacity(0.4),
            inactiveThumbColor: isSuperAdmin ? Colors.grey : _switchInactiveColor, // Gray out if super admin
            inactiveTrackColor: isSuperAdmin ? Colors.grey.withOpacity(0.4) : _switchInactiveColor.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}