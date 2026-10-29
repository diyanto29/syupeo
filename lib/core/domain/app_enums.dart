enum AppRole {
  owner,
  admin,
  cashier,
  waiter,
  kitchen,
  customer;

  static AppRole fromValue(String? value) {
    return AppRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AppRole.owner,
    );
  }
}

extension AppRolePermissions on AppRole {
  bool get canManageCatalog => this == AppRole.owner || this == AppRole.admin;
}
