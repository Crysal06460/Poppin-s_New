enum TypeRemuneration { net, brut }

extension TypeRemunerationLabel on TypeRemuneration {
  String get label => this == TypeRemuneration.net ? 'Net' : 'Brut';
}

/// Résultat du calcul de mensualisation.
class MensualisationResult {
  final double heuresHebdo;
  final double heuresMensualisees;
  final double salaireMensuel;

  const MensualisationResult({
    required this.heuresHebdo,
    required this.heuresMensualisees,
    required this.salaireMensuel,
  });
}

/// Paramètres saisis pour le calcul de mensualisation d'une assistante
/// maternelle. Calcul 100% local, aucune persistance Firestore.
class MensualisationParams {
  final int joursParSemaine;
  final double heuresParJour;
  final bool anneeComplete;
  final int? semainesAccueil;
  final double tarifHoraire;
  final TypeRemuneration typeRemuneration;

  const MensualisationParams({
    required this.joursParSemaine,
    required this.heuresParJour,
    required this.anneeComplete,
    this.semainesAccueil,
    required this.tarifHoraire,
    required this.typeRemuneration,
  });

  MensualisationResult calculer() {
    final double heuresHebdo = joursParSemaine * heuresParJour;
    final int semaines = anneeComplete ? 52 : (semainesAccueil ?? 0);
    final double heuresMensualisees = heuresHebdo * semaines / 12;
    final double salaireMensuel = heuresMensualisees * tarifHoraire;

    return MensualisationResult(
      heuresHebdo: heuresHebdo,
      heuresMensualisees: double.parse(heuresMensualisees.toStringAsFixed(2)),
      salaireMensuel: double.parse(salaireMensuel.toStringAsFixed(2)),
    );
  }
}
