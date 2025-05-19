class Membre {
  final String id;
  final String nom;
  final String prenom;
  final String mamId;
  final String role;
  final String email; // Nouveau champ ajouté

  Membre({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.mamId,
    required this.role,
    this.email = '', // Par défaut vide
  });
}
