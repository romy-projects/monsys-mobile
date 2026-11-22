import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monsys_mobile/core/auth/current_user_provider.dart';
import 'package:monsys_mobile/services/api/api_service.dart';
import 'package:monsys_mobile/services/notification/notification_service.dart';
import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _needsTwoFactor = false;

  /// Sanctum token name shown in the panel's "devices" list.
  static const _deviceName = 'monsys-mobile';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final authStorage = ref.read(authStorageProvider);
      final otp = _otpController.text.trim();

      final response = await apiService.post(
        ApiConstants.login,
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'device_name': _deviceName,
          if (_needsTwoFactor && otp.isNotEmpty) 'one_time_password': otp,
        },
      );

      final payload = response.data;
      final data = payload is Map ? (payload['data'] ?? payload) : null;

      if (response.statusCode == 200 && data is Map) {
        if (data['token'] != null) {
          await authStorage.saveToken(data['token'].toString());
        }

        final rawUser = data['user'];
        final userJson = rawUser is Map
            ? Map<String, dynamic>.from(rawUser)
            : <String, dynamic>{};
        final mustChangePassword = data['must_change_password'] == true ||
            userJson['must_change_password'] == true;
        if (userJson.isNotEmpty) {
          if (mustChangePassword) {
            userJson['must_change_password'] = true;
          }
          await authStorage.saveUser(jsonEncode(userJson));
        }
        await ref.read(currentUserProvider.notifier).reloadFromStorage();

        // Register the FCM push token with the backend. Safe no-op until the
        // Firebase config files are added (TASKLIST.md → M-11).
        unawaited(
            ref.read(notificationServiceProvider).initializeAndRegister());

        if (!mounted) return;
        if (mustChangePassword) {
          context.go('/change-password?forced=1');
        } else {
          context.go('/dashboard');
        }
        return;
      }

      setState(() {
        _errorMessage = 'Login failed. Please check your credentials.';
      });
    } on DioException catch (e) {
      _handleLoginError(e);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Maps panelx login failures: 422 two_factor_required (enrolled HQ account
  /// without a TOTP code), invalid TOTP/recovery code, inactive account (403)
  /// and bad credentials (422 `errors.email`).
  void _handleLoginError(DioException e) {
    if (!mounted) return;
    final payload = e.response?.data;
    final status = e.response?.statusCode;
    final errors = payload is Map ? payload['errors'] : null;
    final message = payload is Map && payload['message'] is String
        ? payload['message'] as String
        : null;

    bool hasField(String key) => errors is Map && errors[key] != null;

    if (status == 422 &&
        (hasField('two_factor_required') ||
            (message?.toLowerCase().contains('two-factor') ?? false))) {
      setState(() {
        _needsTwoFactor = true;
        _errorMessage =
            'Enter the code from your authenticator app (or a recovery code).';
      });
      return;
    }

    if (status == 422 && hasField('one_time_password')) {
      setState(() {
        _needsTwoFactor = true;
        _errorMessage =
            _firstError(errors, 'one_time_password') ?? 'Invalid two-factor code.';
      });
      return;
    }

    if (status == 403) {
      setState(() {
        _errorMessage = message ??
            'Your account is inactive. Please contact your administrator.';
      });
      return;
    }

    if (status == 422) {
      setState(() {
        _errorMessage = _firstError(errors, 'email') ??
            message ??
            'Login failed. Please check your credentials.';
      });
      return;
    }

    setState(() {
      _errorMessage = message ?? 'Unable to sign in. Please try again.';
    });
  }

  String? _firstError(dynamic errors, String key) {
    if (errors is! Map) return null;
    final value = errors[key];
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is String) return value;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dashboard_outlined,
                        size: 60,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Monitoring System',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_needsTwoFactor) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        enabled: !_isLoading,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(
                          labelText: 'Authenticator code',
                          helperText:
                              '6-digit TOTP code, or a recovery code',
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        validator: (value) {
                          if (!_needsTwoFactor) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your two-factor code';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _login();
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Login button
                    FilledButton(
                      onPressed: _isLoading ? null : _login,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _needsTwoFactor ? 'Verify & Sign In' : 'Sign In',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}