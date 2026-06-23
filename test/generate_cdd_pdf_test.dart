import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';
import 'package:poppins_app/features/documents/services/contrat_cdd_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Génère un CDD complet avec tous les champs', () async {
    final model = ContratCddModel(
      // Employeur
      nomNaissanceEmployeur: 'DUPONT',
      nomUsageEmployeur: 'DUPONT',
      prenomEmployeur: 'Marie',
      adresseEmployeur: '14 rue des Lilas',
      villeEmployeur: 'Lyon',
      codePostalEmployeur: '69003',
      telephoneEmployeur: '06 12 34 56 78',
      emailEmployeur: 'marie.dupont@email.com',
      qualiteEmployeur: QualiteCddEmployeur.mere,
      numeroPajemploi: '1234567890',

      // Parent 2
      telephoneParent2: '06 98 76 54 32',
      emailParent2: 'paul.dupont@email.com',
      luEtApprouveParent2: 'Lu et approuvé',

      // Salarié
      nomNaissanceSalarie: 'MARTIN',
      nomUsageSalarie: 'MARTIN',
      prenomSalarie: 'Sophie',
      adresseSalarie: '8 avenue du Parc',
      villeSalarie: 'Lyon',
      codePostalSalarie: '69007',
      telephoneSalarie: '06 45 67 89 01',
      emailSalarie: 'sophie.martin@email.com',
      numeroSecu: '2 85 06 69 123 456 78',
      referenceAgrement: 'AGR-2021-69-001234',
      dateLivraisonAgrement: DateTime(2021, 3, 15),
      dateRenouvellementAgrement: DateTime(2026, 3, 14),
      assuranceRCProNom: 'MAIF',
      assuranceRCProPolice: 'RC-PRO-2024-789012',
      assuranceAutoNom: 'AXA',
      assuranceAutoPolice: 'AUTO-AXA-456789',

      // Lieu de travail
      lieuTravailType: LieuTravailTypeCdd.domicileSalarie,
      lieuTravailAdresse: '8 avenue du Parc, 69007 Lyon',

      // Enfant
      nomEnfant: 'DUPONT',
      prenomEnfant: 'Lucas',
      dateNaissanceEnfant: DateTime(2023, 7, 12),

      // Motif CDD
      motifCdd: 'Accueil temporaire de l\'enfant pendant le congé maternité de la mère',
      personneRemplaceeNom: 'Sophie MARTIN',

      // Durée du contrat
      typeDureeCdd: TypeDureeCdd.datesFixes,
      dateDebutContrat: DateTime(2024, 9, 2),
      dateFinContrat: DateTime(2025, 8, 29),

      // Période d'essai & adaptation
      dureePeriodeEssai: '1 mois',
      dureePeriodeAdaptationJours: 15,
      dateDebutAdaptation: DateTime(2024, 9, 2),
      dateFinAdaptation: DateTime(2024, 9, 16),
      notesAdaptation: 'L\'enfant sera accompagné de sa mère les 3 premiers jours pour faciliter la transition.',

      // Horaires
      nombreSemaines: 46,
      heuresParSemaine: 40.0,
      planningParEcrit: false,
      lignesPlanning: [
        LignePlanningCdd(jourTravail: 'Lundi', horairesTravail: '08h00 – 18h00', nbHeuresTravail: '10h'),
        LignePlanningCdd(jourTravail: 'Mardi', horairesTravail: '08h00 – 18h00', nbHeuresTravail: '10h'),
        LignePlanningCdd(jourTravail: 'Mercredi', horairesTravail: '08h00 – 13h00', nbHeuresTravail: '5h'),
        LignePlanningCdd(jourTravail: 'Jeudi', horairesTravail: '08h00 – 18h00', nbHeuresTravail: '10h'),
        LignePlanningCdd(jourTravail: 'Vendredi', horairesTravail: '08h00 – 13h00', nbHeuresTravail: '5h'),
      ],

      // Rémunération
      salaireHoraireBrut: 3.92,
      salaireHoraireNet: 3.06,
      salaireHoraireMajoreBrut: 4.31,
      salaireHoraireMajoreNet: 3.37,
      tauxMajorationHeuresMajorees: 10.0,
      salaireHoraireMajoreesBrut: 4.31,
      salaireHorairesMajoreesNet: 3.37,
      salaireMensuelBrut: 598.13,
      salaireMensuelNet: 467.25,
      nbHeuresJourneeIndemniteEntretien: 10.0,
      montantHoraireIndemniteEntretien: 0.39,
      repasParSalarie: true,
      montantRepasSalarie: 3.00,
      indemnitesKmParKm: 0.41,
      jourPaiementSalaire: 5,
      accordPajemploiPlus: false,

      // Repos
      jourReposHebdomadaire: 'Dimanche',
      travailReposMajore: true,
      travailReposRecupere: false,

      // Jours fériés
      premierMaiChome: true,
      joursFeriesOrdTravailles: ['Lundi de Pâques', '8 mai', 'Jeudi de l\'Ascension', '14 juillet'],
      tauxMajorationJoursFeries: 10.0,

      // Conditions particulières
      conditionsParticulieres:
          'L\'enfant suit un régime sans gluten. Aucun aliment contenant du gluten ne devra lui être donné.\n'
          'En cas de maladie, les parents seront contactés dans l\'heure. La fièvre supérieure à 38,5°C nécessite une récupération immédiate de l\'enfant.\n'
          'L\'assistant maternel dispose d\'une cour extérieure sécurisée pour les activités de plein air.',

      // Signatures
      lieuSignature: 'Lyon',
      dateSignature: DateTime(2024, 8, 28),
      luEtApprouveEmployeur: 'Lu et approuvé',
      luEtApproveSalarie: 'Lu et approuvé',
    );

    final service = ContratCddPdfService();
    final bytes = await service.genererPdf(model);

    final file = File('/tmp/test_cdd_complet.pdf');
    await file.writeAsBytes(bytes);

    expect(bytes.length, greaterThan(5000));
    print('\n✅ PDF généré : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });
}
