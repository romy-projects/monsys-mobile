import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/shared/widgets/widgets.dart';

/// Read-only profile, backed by the cached UserResource snapshot and refreshed
/// from GET /me. Editing is an HQ action (Master Data → Users) in panelx.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          message: 'Failed to load your profile',
          onRetry: () => ref.read(currentUserProvider.notifier).refreshFromApi(),
        ),
        data: (user) => RefreshIndicator(
          onRefresh: () =>
              ref.read(currentUserProvider.notifier).refreshFromApi(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, user),
              const SizedBox(height: 16),
              _buildInfoCard(context, user),
              const SizedBox(height: 16),
              _buildPermissionsCard(context, user),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/change-password'),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change Password'),
              ),
              const SizedBox(height: 8),
              Text(
                'Name, role and branch changes are managed by HQ in '
                'Master Data → Users.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserAccount user) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                user.initials,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name.isEmpty ? 'Unknown user' : user.name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (user.email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.email,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _pill(user.roleLabel, scheme.primary),
                _pill(user.scopeLabel, scheme.secondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
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

  Widget _buildInfoCard(BuildContext context, UserAccount user) {
    final passwordChanged = user.passwordChangedAt == null
        ? '—'
        : DateFormat('dd MMM yyyy').format(user.passwordChangedAt!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _infoRow(context, Icons.badge_outlined, 'User ID',
                user.id == null ? '—' : '#${user.id}'),
            _infoRow(context, Icons.person_outline, 'Name',
                user.name.isEmpty ? '—' : user.name),
            _infoRow(context, Icons.email_outlined, 'Email',
                user.email.isEmpty ? '—' : user.email),
            _infoRow(context, Icons.phone_outlined, 'Phone', user.phone ?? '—'),
            _infoRow(
                context, Icons.verified_user_outlined, 'Role', user.roleLabel),
            _infoRow(context, Icons.public, 'Scope', user.scopeLabel),
            _infoRow(
                context,
                Icons.storefront_outlined,
                'Branch',
                user.branchName == null
                    ? '—'
                    : '${user.branchName}'
                        '${user.branchCode != null ? ' (${user.branchCode})' : ''}'),
            _infoRow(
                context,
                Icons.toggle_on_outlined,
                'Status',
                user.status == null
                    ? (user.isActive ? 'Active' : 'Unknown')
                    : user.status!),
            _infoRow(context, Icons.password, 'Password updated',
                passwordChanged),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context, UserAccount user) {
    final theme = Theme.of(context);
    final permissions = <({String label, bool granted})>[
      (label: 'HQ scope', granted: user.isHqRole),
      (label: 'Approve orders', granted: user.canApprove),
      (label: 'View finance', granted: user.canViewFinance),
      (label: 'Manage users', granted: user.canManageUsers),
      (label: 'Read-only role', granted: user.isReadOnlyRole),
      (label: 'Super admin', granted: user.isSuperAdmin),
      (label: 'Password rotation pending', granted: user.hasPendingPasswordRotation),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final permission in permissions)
                  Chip(
                    avatar: Icon(
                      permission.granted
                          ? Icons.check_circle
                          : Icons.remove_circle_outline,
                      size: 16,
                      color: permission.granted ? Colors.green : Colors.grey,
                    ),
                    label: Text(permission.label, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}