import 'dart:convert';

/// Parsed snapshot of the authenticated user, matching the shape returned by
/// panelx `App\Http\Resources\UserResource` (used by POST /auth/login and
/// GET /me):
///
/// ```json
/// {
///   "id": 1, "name": "...", "email": "...", "role": "owner_pusat",
///   "phone": "...", "status": "active", "branch_id": 1,
///   "must_change_password": false,
///   "password_changed_at": "2026-01-01T00:00:00.000000Z",
///   "branch": {"id": 1, "name": "...", "code": "..."},
///   "permissions": {
///     "can_approve_orders": true,
///     "can_view_finance": true,
///     "is_owner_pusat": true,
///     "is_regional_leader": false
///   }
/// }
/// ```
class UserAccount {
  const UserAccount({
    this.id,
    this.name = '',
    this.email = '',
    this.role,
    this.phone,
    this.status,
    this.branchId,
    this.branchName,
    this.branchCode,
    this.mustChangePassword = false,
    this.passwordChangedAt,
    bool canApproveOrders = false,
    bool canViewFinance = false,
    bool isOwnerPusat = false,
    bool isRegionalLeader = false,
    bool isSuperAdmin = false,
  })  : _canApproveOrders = canApproveOrders,
        _canViewFinance = canViewFinance,
        _isOwnerPusat = isOwnerPusat,
        _isRegionalLeader = isRegionalLeader,
        _isSuperAdmin = isSuperAdmin;

  factory UserAccount.fromJsonString(String userJson) {
    try {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        return UserAccount.fromJson(decoded);
      }
    } catch (_) {}
    return const UserAccount();
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'];
    final perms = permissions is Map ? permissions : const {};
    final branch = json['branch'];
    final branchMap = branch is Map ? branch : const {};

    return UserAccount(
      id: _asInt(json['id']),
      name: (json['name'] ?? json['email'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: json['role']?.toString(),
      phone: _asOptionalString(json['phone']),
      status: _asOptionalString(json['status']),
      branchId: _asInt(json['branch_id']),
      branchName: _asOptionalString(branchMap['name']),
      branchCode: _asOptionalString(branchMap['code']),
      mustChangePassword: json['must_change_password'] == true,
      passwordChangedAt: _asDateTime(json['password_changed_at']),
      canApproveOrders: perms['can_approve_orders'] == true,
      canViewFinance: perms['can_view_finance'] == true,
      isOwnerPusat: perms['is_owner_pusat'] == true,
      isRegionalLeader: perms['is_regional_leader'] == true,
      isSuperAdmin: perms['is_super_admin'] == true,
    );
  }

  final int? id;
  final String name;
  final String email;
  final String? role;
  final String? phone;
  final String? status;
  final int? branchId;
  final String? branchName;
  final String? branchCode;
  final bool mustChangePassword;
  final DateTime? passwordChangedAt;

  final bool _canApproveOrders;
  final bool _canViewFinance;
  final bool _isOwnerPusat;
  final bool _isRegionalLeader;
  final bool _isSuperAdmin;

  // Panelx role identifiers (hierarchy: super_admin > owner_pusat >
  // regional_leader > owner_cabang > staff_gudang).
  static const String roleSuperAdmin = 'super_admin';
  static const String roleOwnerPusat = 'owner_pusat';
  static const String roleRegionalLeader = 'regional_leader';
  static const String roleOwnerCabang = 'owner_cabang';
  static const String roleStaffGudang = 'staff_gudang';

  /// super_admin is a protected system role in panelx and holds every
  /// permission. `UserResource` exposes it through `role` (the permissions
  /// block may also carry `is_super_admin`, honoured when present).
  bool get isSuperAdmin => _isSuperAdmin || role == roleSuperAdmin;

  bool get isOwnerPusat => _isOwnerPusat || role == roleOwnerPusat;

  bool get isRegionalLeader => _isRegionalLeader || role == roleRegionalLeader;

  /// Head-quarter roles: per panelx Phase 8 RBAC these see cross-branch
  /// summaries, the whole order resource and finance data. Branch-scoped roles
  /// (owner_cabang, staff_gudang) only see their own branch.
  bool get isHqRole => isSuperAdmin || isOwnerPusat || isRegionalLeader;

  /// Branch-scoped roles — they receive `/dashboard/branch` and may only
  /// create Purchase Orders.
  bool get isBranchRole =>
      role == roleOwnerCabang || role == roleStaffGudang;

  /// staff_gudang is read-only in panelx (no mutations/close/order actions).
  bool get isReadOnlyRole => role == roleStaffGudang;

  bool get canApprove => _canApproveOrders || isHqRole;

  bool get canViewFinance => _canViewFinance || isSuperAdmin || isOwnerPusat;

  /// Master data + user administration (panelx `users.*` / `master_data.*`).
  /// owner_pusat holds every permission except `access_control.manage` and
  /// `impersonation.start`; super_admin holds everything.
  bool get canManageUsers => isSuperAdmin || isOwnerPusat;

  /// Suspended/inactive accounts are rejected at login, but the snapshot still
  /// carries the status for display.
  bool get isActive => status == null || status == 'active';

  /// True when the user must rotate the password before using the app
  /// (`must_change_password` from login / GET /me).
  bool get hasPendingPasswordRotation => mustChangePassword;

  String get roleLabel {
    switch (role) {
      case roleSuperAdmin:
        return 'Super Admin';
      case roleOwnerPusat:
        return 'Owner Pusat';
      case roleRegionalLeader:
        return 'Regional Leader';
      case roleOwnerCabang:
        return 'Owner Cabang';
      case roleStaffGudang:
        return 'Staff Gudang';
      default:
        return role == null || role!.isEmpty ? 'No role' : role!;
    }
  }

  /// Short scope description used on the account header / dashboard chip.
  String get scopeLabel {
    if (isSuperAdmin) return 'HQ · Full access';
    if (isHqRole) return 'HQ · All branches';
    if (isBranchRole) {
      return branchName == null || branchName!.isEmpty
          ? 'Branch scoped'
          : 'Branch · $branchName';
    }
    return branchName ?? 'Unscoped';
  }

  String get initials {
    final source = name.trim();
    if (source.isEmpty) return 'U';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _asOptionalString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
