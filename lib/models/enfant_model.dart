class Enfant {
  final String id;
  final String nom;
  final String prenom;
  final DateTime dateNaissance;
  final List<String> membresIds; // Liste des ass. mat. qui gardent cet enfant
  final String? photoUrl;
  final String? couleur; // Couleur pour le planning

  Enfant({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.membresIds,
    this.photoUrl,
    this.couleur,
  });
}
