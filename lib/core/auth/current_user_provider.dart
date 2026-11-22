import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monsys_mobile/core/auth/auth_storage.dart';
import 'package:monsys_mobile/core/auth/user_account.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/services/api/api_service.dart';

/// Single source of truth for the signed-in user snapshot.
///
/// `build()` reads the cached UserResource JSON written at login, so screens
/// render immediately and offline. `refreshFromApi()` re-fetches GET /me and
/// persists it (panelx wraps the resource in a `data` envelope).
class CurrentUserNotifier extends AsyncNotifier<UserAccount> {
  @override
  Future<UserAccount> build() async {
    final userJson = await ref.read(authStorageProvider).getUser();
    return UserAccount.fromJsonString(userJson ?? '');
  }

  /// Re-reads whatever login just persisted (no network round-trip).
  Future<UserAccount> reloadFromStorage() async {
    final userJson = await ref.read(authStorageProvider).getUser();
    final user = UserAccount.fromJsonString(userJson ?? '');
    state = AsyncData(user);
    return user;
  }

  /// GET /me, persist the fresh snapshot and publish it.
  Future<UserAccount> refreshFromApi() async {
    try {
      final response = await ref.read(apiServiceProvider).get(ApiConstants.me);
      final payload = response.data;
      final data = payload is Map ? (payload['data'] ?? payload) : null;
      if (response.statusCode == 200 && data is Map) {
        final json = Map<String, dynamic>.from(data);
        await ref.read(authStorageProvider).saveUser(jsonEncode(json));
        final user = UserAccount.fromJson(json);
        state = AsyncData(user);
        return user;
      }
    } catch (_) {
      // Keep the cached snapshot on failure — the account screen falls back to
      // whatever was persisted at login.
    }
    final cached = state.valueOrNull ?? const UserAccount();
    state = AsyncData(cached);
    return cached;
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, UserAccount>(
  CurrentUserNotifier.new,
);
