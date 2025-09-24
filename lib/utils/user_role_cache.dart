class UserRoleCache {
  static String? lastKnownRole;
  static String? lastKnownStructureType;

  static void setRole(String? role) {
    lastKnownRole = role;
  }

  static void setStructureType(String? structureType) {
    lastKnownStructureType = structureType;
  }

  static bool get isParent => lastKnownRole == 'parent';
}
