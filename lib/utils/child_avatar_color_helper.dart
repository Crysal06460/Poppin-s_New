import 'package:flutter/material.dart';

/// Helper methods to keep child avatar colors consistent across screens.
class ChildAvatarColorHelper {
  const ChildAvatarColorHelper._();

  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);

  static const List<Color> _mamMemberColorPalette = <Color>[
    Color(0xFF3D9DF2), // Bleu principal
    Color(0xFF2ECC71), // Vert
    Color(0xFFFFC107), // Jaune
    Color(0xFF9B59B6), // Violet
    Color(0xFFE67E22), // Orange
    Color(0xFF1ABC9C), // Turquoise
    Color(0xFFEB5757), // Rouge doux
  ];

  static const Color mamUnassignedColor = Color(0xFF95A5A6);

  /// Normalises an email value by trimming and lowercasing it.
  static String normalizeEmail(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim().toLowerCase();
  }

  /// Returns the default avatar color when MAM specific colouring is not used.
  static Color defaultColorForGender(String? gender) {
    final String normalized = gender?.toLowerCase().trim() ?? '';
    if (normalized == 'fille') {
      return primaryRed;
    }
    return primaryBlue;
  }

  /// Builds the color assignment map for MAM members based on the given children.
  static Map<String, Color> buildMamAssignmentsFromChildren(
      Iterable<Map<String, dynamic>> children) {
    final Set<String> uniqueEmails = <String>{};
    for (final Map<String, dynamic> child in children) {
      final String email = normalizeEmail(child['assignedMemberEmail']);
      if (email.isNotEmpty) {
        uniqueEmails.add(email);
      }
    }

    final List<String> sortedEmails = uniqueEmails.toList()..sort();
    final Map<String, Color> assignments = <String, Color>{};
    for (int i = 0; i < sortedEmails.length; i++) {
      assignments[sortedEmails[i]] =
          _mamMemberColorPalette[i % _mamMemberColorPalette.length];
    }
    return assignments;
  }

  /// Resolves the avatar color for a child, using the MAM assignments when needed.
  static Color resolveAvatarColor({
    required bool isMamStructure,
    required Map<String, Color> mamAssignments,
    String? assignedMemberEmail,
    String? gender,
  }) {
    if (isMamStructure) {
      final String normalizedEmail = normalizeEmail(assignedMemberEmail);
      if (normalizedEmail.isEmpty) {
        return mamUnassignedColor;
      }
      return mamAssignments[normalizedEmail] ?? mamUnassignedColor;
    }

    return defaultColorForGender(gender);
  }
}
