import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/services/notification/notification_service.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Account tab — profile summary, permission-gated shortcuts, administration
/// (owner_pusat / super_admin) and session controls.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  /// Mirrors pubspec.yaml `version: 1.0.0+1`.
  static const _appVersion = '1.0.0';

  bool _busy = false;

  Future<void> _refreshProfile() async {
    await ref.read(currentUserProvider.notifier).refreshFromApi();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiServiceProvider).post(ApiConstants.logout);
    } catch (_) {
      // Logout must succeed locally even when the network call fails.
    }
    try {
      await ref.read(notificationServiceProvider).revokeDevice();
    } catch (_) {}
    await ref.read(authStorageProvider).clearAll();
    ref.invalidate(currentUserProvider);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh profile',
            onPressed: _busy ? null : _refreshProfile,
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          message: 'Failed to load your account',
          onRetry: _refreshProfile,
        ),
        data: (user) => RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildHeader(user),
              if (user.hasPendingPasswordRotation) ...[
                const SizedBox(height: 12),
                _buildPasswordBanner(),
              ],
              const SizedBox(height: 20),
              _sectionHeader('Account'),
              _tile(
                Icons.person_outline,
                'Profile',
                'Name, role, branch and permissions',
                onTap: () => context.push('/profile'),
              ),
              _tile(
                Icons.lock_outline,
                'Change Password',
                'Current password and new password (min 8 characters)',
                onTap: () => context.push('/change-password'),
              ),
              const SizedBox(height: 20),
              _sectionHeader('Workspace'),
              _tile(
                Icons.receipt_long_outlined,
                'Orders',
                user.isHqRole
                    ? 'Sales, loading and purchase orders'
                    : 'Your purchase orders',
                onTap: () => context.go('/orders'),
              ),
              _tile(
                Icons.inventory_2_outlined,
                'Stock',
                'Stock items, mutations and daily closes',
                onTap: () => context.go('/stock'),
              ),
              _tile(
                Icons.swap_horiz,
                'Tabung Sirkulasi',
                'Cylinder circulation ledger',
                onTap: () => context.push('/cylinder-circulations'),
              ),
              _tile(
                Icons.bar_chart,
                'Reports',
                'Profit & loss, stock, shipments and more',
                onTap: () => context.go('/reports'),
              ),
              if (user.canViewFinance)
                _tile(
                  Icons.receipt,
                  'Finance',
                  'Invoices and transportir payables',
                  onTap: () => context.push('/finance'),
                ),
              if (user.canManageUsers) ...[
                const SizedBox(height: 20),
                _sectionHeader('Administration'),
                _tile(
                  Icons.dataset_outlined,
                  'Master Data & Users',
                  'Branches, users, transportirs, vehicles, prices',
                  onTap: () => context.push('/master-data'),
                ),
              ],
              const SizedBox(height: 20),
              _sectionHeader('About'),
              _tile(
                Icons.info_outline,
                'App version',
                _appVersion,
              ),
              _tile(
                Icons.logout,
                _busy ? 'Signing out…' : 'Logout',
                'End this session on the device',
                destructive: true,
                onTap: _busy ? null : _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserAccount user) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    user.initials,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Unknown user' : user.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (user.email.isNotEmpty)
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(user.roleLabel, scheme.primary),
                _badge(user.scopeLabel, scheme.secondary),
                _badge(
                  user.isActive ? 'Active' : (user.status ?? 'Inactive'),
                  user.isActive ? Colors.green : Colors.red,
                ),
                if (user.isSuperAdmin)
                  _badge('Full permissions', Colors.deepPurple),
              ],
            ),
            if (user.phone != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(user.phone!, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPasswordBanner() {
    return Material(
      color: Colors.amber.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/change-password?forced=1'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.lock_clock, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your password must be changed before continuing.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    bool destructive = false,
  }) {
    final color = destructive
        ? Colors.red
        : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: destructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
