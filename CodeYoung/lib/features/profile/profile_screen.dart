import 'package:flutter/material.dart';
import 'package:codeyoung/core/theme/app_theme.dart';
import 'package:codeyoung/core/widgets/app_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  
  final Map<String, dynamic> _userProfile = {'name': 'CodeYoung Learner', 'email': 'learner@codeyoung.com'};
  final Map<String, dynamic> _userStats = {'lessonsCompleted': 0, 'hoursLearned': 0, 'projectsBuilt': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadData() {
    final name = _userProfile['name'] as String? ?? 'CodeYoung Learner';
    final email = _userProfile['email'] as String? ?? 'learner@codeyoung.com';
    
    _nameController = TextEditingController(text: name);
    _emailController = TextEditingController(text: email);
  }

  void _showEditDialog() {
    final nameEditingController = TextEditingController(text: _userProfile['name'] as String? ?? 'CodeYoung Learner');
    final emailEditingController = TextEditingController(text: _userProfile['email'] as String? ?? 'learner@codeyoung.com');
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameEditingController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailEditingController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.contains('@') ? null : 'Enter valid email',
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final name = nameEditingController.text;
              final email = emailEditingController.text;
              if (name.isNotEmpty && email.contains('@')) {
                setState(() {
                  _userProfile['name'] = name;
                  _userProfile['email'] = email;
                  _nameController.text = name;
                  _emailController.text = email;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to logout? You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _userProfile['name'] as String? ?? 'CodeYoung Learner';
    final email = _userProfile['email'] as String? ?? 'learner@codeyoung.com';
    final lessonsCompleted = _userStats['lessonsCompleted'] as int? ?? 0;
    final hoursLearned = _userStats['hoursLearned'] as int? ?? 0;
    final projectsBuilt = _userStats['projectsBuilt'] as int? ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppHeader(
        showBack: true,
        subtitle: 'Profile',
        // Legacy screen: popped with the Navigator, not GoRouter.
        onBack: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(name, email, isDark),
              const SizedBox(height: 20),
              _buildStatsRow(lessonsCompleted, hoursLearned, projectsBuilt, isDark),
              const SizedBox(height: 24),
              _buildQuickActions(isDark),
              const SizedBox(height: 24),
              _buildSettings(isDark),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, String email, bool isDark) {
    return Card(
      elevation: isDark ? 4 : 2,
      color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.primaryBlue,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showEditDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.3 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit, color: AppColors.primaryBlue, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: TextStyle(
                      color: isDark ? AppColors.textOnDark.withValues(alpha: 0.7) : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int lessonsCompletedVal, int hoursLearnedVal, int projectsBuiltVal, bool isDark) {
    return Row(
      children: [
        _buildGradientStatCard('Lessons', lessonsCompletedVal, AppColors.primaryBlue, isDark),
        const SizedBox(width: 10),
        _buildGradientStatCard('Hours', hoursLearnedVal, AppColors.accentGreen, isDark),
        const SizedBox(width: 10),
        _buildGradientStatCard('Projects', projectsBuiltVal, AppColors.accentOrange, isDark),
      ],
    );
  }

  Widget _buildGradientStatCard(String label, int value, Color color, bool isDark) {
    return Expanded(
      child: Card(
        elevation: isDark ? 4 : 2,
        color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: isDark ? 0.3 : 0.15),
                      color.withValues(alpha: isDark ? 0.25 : 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconForStat(label), size: 24, color: color),
              ),
              const SizedBox(height: 10),
              Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.textOnDark.withValues(alpha: 0.7) : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForStat(String label) {
    switch (label) {
      case 'Lessons':
        return Icons.book_outlined;
      case 'Hours':
        return Icons.access_time;
      case 'Projects':
        return Icons.code;
      default:
        return Icons.bar_chart;
    }
  }

  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildFeatureCard('Security', 'Change password', Icons.security, AppColors.primaryBlue, isDark, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password settings'),
              backgroundColor: AppColors.primaryBlue,
            ),
          );
        })),
        const SizedBox(width: 10),
        Expanded(child: _buildFeatureCard('Notifications', 'Manage alerts', Icons.notifications, AppColors.accentGreen, isDark, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        })),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String subtitle, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return Card(
      elevation: isDark ? 4 : 2,
      color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: isDark ? 0.3 : 0.15), color.withValues(alpha: isDark ? 0.25 : 0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildSettings(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureCard('Personal Info', 'Update your name and email', Icons.person_outline, AppColors.primaryBlue, isDark, _showEditDialog),
        const SizedBox(height: 12),
        _buildFeatureCard('Logout', 'Sign out of your account', Icons.logout, AppColors.error, isDark, _logout),
      ],
    );
  }
}