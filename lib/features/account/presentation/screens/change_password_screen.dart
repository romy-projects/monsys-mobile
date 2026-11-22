import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';

/// Password rotation form.
///
/// Panelx `POST /auth/password` expects:
/// `current_password`, `password`, `password_confirmation` with
/// `password|min:8|confirmed`. A successful change clears the user's
/// `must_change_password` flag server-side.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  /// True when the user was redirected here by the router because panelx
  /// flagged `must_change_password` (no cancel / no back arrow).
  final bool forced;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(apiServiceProvider).post(
            ApiConstants.authPassword,
            data: {
              'current_password': _currentController.text,
              'password': _newController.text,
              'password_confirmation': _confirmController.text,
            },
          );
      if (!mounted) return;

      if (response.statusCode == 200) {
        // Re-fetch /me so must_change_password + password_changed_at refresh.
        await ref.read(currentUserProvider.notifier).refreshFromApi();
        // Defensive: the /me refresh degrades silently when offline. The
        // password change already succeeded server-side, so make sure the
        // cached snapshot no longer forces the rotation redirect.
        await _clearCachedRotationFlag();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        if (widget.forced) {
          context.go('/dashboard');
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go('/account');
        }
        return;
      }

      setState(() {
        _submitting = false;
        _errorMessage = _extractMessage(response.data) ??
            'Failed to change the password (HTTP ${response.statusCode}).';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _extractMessage(e.response?.data) ??
            'Failed to change the password. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Failed to change the password. Please try again.';
      });
    }
  }

  /// Clears `must_change_password` in the persisted snapshot so the router
  /// stops redirecting even if the /me refresh could not reach the API.
  Future<void> _clearCachedRotationFlag() async {
    final storage = ref.read(authStorageProvider);
    final cached = await storage.getUser();
    if (cached == null) return;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is Map && decoded['must_change_password'] == true) {
        decoded['must_change_password'] = false;
        await storage.saveUser(jsonEncode(decoded));
        await ref.read(currentUserProvider.notifier).reloadFromStorage();
      }
    } catch (_) {
      // Ignore malformed cache — refreshFromApi already replaced it on success.
    }
  }

  String? _extractMessage(dynamic payload) {
    if (payload is! Map) return null;
    final message = payload['message'];
    if (message is String && message.isNotEmpty) return message;
    final errors = payload['errors'];
    if (errors is Map) {
      final messages = errors.values
          .whereType<List>()
          .expand((value) => value)
          .whereType<String>()
          .toList();
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }

  Future<void> _signOut() async {
    try {
      await ref.read(apiServiceProvider).post(ApiConstants.logout);
    } catch (_) {}
    await ref.read(authStorageProvider).clearAll();
    ref.invalidate(currentUserProvider);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.forced ? 'Set a new password' : 'Change Password',
        ),
        automaticallyImplyLeading: !widget.forced,
        actions: [
          if (widget.forced)
            TextButton(
              onPressed: _submitting ? null : _signOut,
              child: const Text('Logout'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.forced) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your account requires a new password before you '
                            'can continue.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _passwordField(
                  controller: _currentController,
                  label: 'Current password',
                  icon: Icons.lock_outline,
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _newController,
                  label: 'New password',
                  icon: Icons.lock,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  helper: 'At least 8 characters',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a new password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (value == _currentController.text) {
                      return 'The new password must be different';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _confirmController,
                  label: 'Confirm new password',
                  icon: Icons.lock,
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm the new password';
                    }
                    if (value != _newController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Change Password'),
                ),
                if (!widget.forced) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting ? null : () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enableSuggestions: false,
      autocorrect: false,
      enabled: !_submitting,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
