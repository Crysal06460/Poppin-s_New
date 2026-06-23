import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/features/documents/models/contrat_cdi_model.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';
import 'package:poppins_app/features/documents/services/contrat_cdi_pdf_service.dart';
import 'package:poppins_app/features/documents/services/contrat_cdd_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Données communes famille Dupont / Sophie Martin
  final employeur = (
    nom: 'DUPONT', prenom: 'Marie',
    adresse: '14 rue des Lilas', ville: 'Lyon', cp: '69003',
    tel: '06 12 34 56 78', email: 'marie.dupont@email.com',
    pajemploi: '1234567890',
  );
  final salarie = (
    nom: 'MARTIN', prenom: 'Sophie',
    adresse: '8 avenue du Parc', ville: 'Lyon', cp: '69007',
    tel: '06 45 67 89 01', email: 'sophie.martin@email.com',
    secu: '2 85 06 69 123 456 78',
    agrement: 'AGR-2021-69-001234',
    dateAgrement: DateTime(2021, 3, 15),
    dateRenouvellement: DateTime(2026, 3, 14),
    rcPro: 'MAIF', rcProPolice: 'RC-PRO-2024-789012',
    auto: 'AXA', autoPolice: 'AUTO-AXA-456789',
  );

  test('Génère CDI complet', () async {
    final model = ContratCdiModel(
      // Employeur
      nomNaissanceEmployeur: employeur.nom, nomUsageEmployeur: employeur.nom,
      prenomEmployeur: employeur.prenom,
      adresseEmployeur: employeur.adresse, villeEmployeur: employeur.ville,
      codePostalEmployeur: employeur.cp,
      telephoneEmployeur: employeur.tel, emailEmployeur: employeur.email,
      qualiteEmployeur: QualiteCdiEmployeur.mere,
      numeroPajemploi: employeur.pajemploi,
      telephoneParent2: '06 98 76 54 32', emailParent2: 'paul.dupont@email.com',

      // Salarié
      nomNaissanceSalarie: salarie.nom, nomUsageSalarie: salarie.nom,
      prenomSalarie: salarie.prenom,
      adresseSalarie: salarie.adresse, villeSalarie: salarie.ville,
      codePostalSalarie: salarie.cp,
      telephoneSalarie: salarie.tel, emailSalarie: salarie.email,
      numeroSecu: salarie.secu,
      referenceAgrement: salarie.agrement,
      dateLivraisonAgrement: salarie.dateAgrement,
      dateRenouvellementAgrement: salarie.dateRenouvellement,
      assuranceRCProNom: salarie.rcPro, assuranceRCProPolice: salarie.rcProPolice,
      assuranceAutoNom: salarie.auto, assuranceAutoPolice: salarie.autoPolice,

      // Lieu
      lieuTravailType: LieuTravailType.domicileSalarie,
      lieuTravailAdresse: '8 avenue du Parc, 69007 Lyon',

      // Enfant
      nomEnfant: 'DUPONT', prenomEnfant: 'Lucas',
      dateNaissanceEnfant: DateTime(2023, 7, 12),
      dateEmbauche: DateTime(2024, 9, 2),

      // Période essai/adaptation
      dureePeriodeEssai: '3 mois',
      dureePeriodeAdaptationJours: 15,
      dateDebutAdaptation: DateTime(2024, 9, 2),
      dateFinAdaptation: DateTime(2024, 9, 16),
      notesAdaptation: 'L\'enfant sera accompagné de sa mère les 3 premiers jours pour faciliter la transition.',

      // Horaires
      typeAccueil: TypeAccueilCdi.cas2_46semaines,
      nombreSemainesGarde: 46,
      heuresParSemaine: 40.0,
      planningParEcrit: false,
      lignesPlanning: [
        LignePlanning(jourTravail: 'Lundi',    horairesTravail: '08h00 - 18h00', nbHeuresTravail: '10h'),
        LignePlanning(jourTravail: 'Mardi',    horairesTravail: '08h00 - 18h00', nbHeuresTravail: '10h'),
        LignePlanning(jourTravail: 'Mercredi', horairesTravail: '08h00 - 13h00', nbHeuresTravail: '5h'),
        LignePlanning(jourTravail: 'Jeudi',    horairesTravail: '08h00 - 18h00', nbHeuresTravail: '10h'),
        LignePlanning(jourTravail: 'Vendredi', horairesTravail: '08h00 - 13h00', nbHeuresTravail: '5h'),
      ],

      // Rémunération
      salaireHoraireBrut: 3.92, salaireHoraireNet: 3.06,
      salaireHoraireMajoreBrut: 4.31, salaireHoraireMajoreNet: 3.37,
      tauxMajorationHeuresMajorees: 10.0,
      salaireHoraireMajoreesBrut: 4.31, salaireHorairesMajoreesNet: 3.37,
      salaireMensuelBrut: 598.13, salaireMensuelNet: 467.25,
      nbHeuresJourneeIndemniteEntretien: 10.0,
      montantHoraireIndemniteEntretien: 0.39,
      repasParSalarie: true, montantRepasSalarie: 3.00,
      indemnitesKmParKm: 0.41,
      jourPaiementSalaire: 5,

      // Repos
      jourReposHebdomadaire: 'Dimanche',
      travailReposMajore: true,

      // Jours fériés
      premierMaiChome: true,
      joursFeriesOrdTravailles: ['Lundi de Paques', '8 mai', 'Jeudi de l\'Ascension', '14 juillet'],
      tauxMajorationJoursFeries: 10.0,

      // Congés
      modeVersementCP: ModeVersementCP.enJuin,

      // Conditions
      conditionsParticulieres:
          'L\'enfant suit un regime sans gluten. Aucun aliment contenant du gluten ne devra lui etre donne.\n'
          'En cas de maladie, les parents seront contactes dans l\'heure.',

      // Signatures
      lieuSignature: 'Lyon', dateSignature: DateTime(2024, 8, 28),
      luEtApprouveEmployeur: 'Lu et approuve', luEtApproveSalarie: 'Lu et approuve',
      luEtApprouveParent2: 'Lu et approuve',
    );

    final bytes = await ContratCdiPdfService().genererPdf(model);
    final file = File('/tmp/test_cdi_complet.pdf');
    await file.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(5000));
    print('\n✅ CDI genere : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });

  test('Génère CDD complet avec Parent 2', () async {
    final model = ContratCddModel(
      // Employeur
      nomNaissanceEmployeur: employeur.nom, nomUsageEmployeur: employeur.nom,
      prenomEmployeur: employeur.prenom,
      adresseEmployeur: employeur.adresse, villeEmployeur: employeur.ville,
      codePostalEmployeur: employeur.cp,
      telephoneEmployeur: employeur.tel, emailEmployeur: employeur.email,
      qualiteEmployeur: QualiteCddEmployeur.mere,
      numeroPajemploi: employeur.pajemploi,
      telephoneParent2: '06 98 76 54 32', emailParent2: 'paul.dupont@email.com',
      luEtApprouveParent2: 'Lu et approuve',

      // Salarié
      nomNaissanceSalarie: salarie.nom, nomUsageSalarie: salarie.nom,
      prenomSalarie: salarie.prenom,
      adresseSalarie: salarie.adresse, villeSalarie: salarie.ville,
      codePostalSalarie: salarie.cp,
      telephoneSalarie: salarie.tel, emailSalarie: salarie.email,
      numeroSecu: salarie.secu,
      referenceAgrement: salarie.agrement,
      dateLivraisonAgrement: salarie.dateAgrement,
      dateRenouvellementAgrement: salarie.dateRenouvellement,
      assuranceRCProNom: salarie.rcPro, assuranceRCProPolice: salarie.rcProPolice,
      assuranceAutoNom: salarie.auto, assuranceAutoPolice: salarie.autoPolice,

      // Lieu
      lieuTravailType: LieuTravailTypeCdd.domicileSalarie,
      lieuTravailAdresse: '8 avenue du Parc, 69007 Lyon',

      // Enfant
      nomEnfant: 'DUPONT', prenomEnfant: 'Lucas',
      dateNaissanceEnfant: DateTime(2023, 7, 12),

      // Motif CDD
      motifCdd: 'Accueil temporaire de l\'enfant pendant le conge maternite de la mere',
      personneRemplaceeNom: 'Sophie MARTIN',

      // Durée
      typeDureeCdd: TypeDureeCdd.datesFixes,
      dateDebutContrat: DateTime(2024, 9, 2),
      dateFinContrat: DateTime(2025, 8, 29),

      // Période essai/adaptation
      dureePeriodeEssai: '1 mois',
      dureePeriodeAdaptationJours: 15,
      dateDebutAdaptation: DateTime(2024, 9, 2),
      dateFinAdaptation: DateTime(2024, 9, 16),
      notesAdaptation: 'L\'enfant sera accompagne de sa mere les 3 premiers jours pour faciliter la transition.',

      // Horaires
      nombreSemaines: 46,
      heuresParSemaine: 40.0,
      planningParEcrit: false,
      lignesPlanning: [
        LignePlanningCdd(jourTravail: 'Lundi',    horairesTravail: '08h00 - 18h00', nbHeuresTravail: '10h'),
        LignePlanningCdd(jourTravail: 'Mardi',    horairesTravail: '08h00 - 18h00', nbHeuresTravail: '10h'),
        LignePlanningCdd(jourTravail: 'Mercredi', horairesTravail: '08h00 - 13h00', nbHeuresTravail: '5h'),
        LignePlanningCdd(jourTravail: 'Jeudi',    horairesTravail: '08h00 - 18h00', nbHeuresTravail: '10h'),
        LignePlanningCdd(jourTravail: 'Vendredi', horairesTravail: '08h00 - 13h00', nbHeuresTravail: '5h'),
      ],

      // Rémunération
      salaireHoraireBrut: 3.92, salaireHoraireNet: 3.06,
      salaireHoraireMajoreBrut: 4.31, salaireHoraireMajoreNet: 3.37,
      tauxMajorationHeuresMajorees: 10.0,
      salaireHoraireMajoreesBrut: 4.31, salaireHorairesMajoreesNet: 3.37,
      salaireMensuelBrut: 598.13, salaireMensuelNet: 467.25,
      nbHeuresJourneeIndemniteEntretien: 10.0,
      montantHoraireIndemniteEntretien: 0.39,
      repasParSalarie: true, montantRepasSalarie: 3.00,
      indemnitesKmParKm: 0.41,
      jourPaiementSalaire: 5,

      // Repos
      jourReposHebdomadaire: 'Dimanche',
      travailReposMajore: true,

      // Jours fériés
      premierMaiChome: true,
      joursFeriesOrdTravailles: ['Lundi de Paques', '8 mai', 'Jeudi de l\'Ascension', '14 juillet'],
      tauxMajorationJoursFeries: 10.0,

      // Conditions
      conditionsParticulieres:
          'L\'enfant suit un regime sans gluten. En cas de maladie, les parents seront contactes dans l\'heure.\n'
          'La fievre superieure a 38,5 C necessite une recuperation immediate de l\'enfant.',

      // Signatures
      lieuSignature: 'Lyon', dateSignature: DateTime(2024, 8, 28),
      luEtApprouveEmployeur: 'Lu et approuve', luEtApproveSalarie: 'Lu et approuve',
    );

    final bytes = await ContratCddPdfService().genererPdf(model);
    final file = File('/tmp/test_cdd_complet.pdf');
    await file.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(5000));
    print('\n✅ CDD genere : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });
}
