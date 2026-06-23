import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/features/documents/models/contrat_cdi_model.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';
import 'package:poppins_app/features/documents/services/contrat_cdi_pdf_service.dart';
import 'package:poppins_app/features/documents/services/contrat_cdd_pdf_service.dart';
import 'package:poppins_app/features/documents/services/avenant_pdf_service.dart';
import 'package:poppins_app/features/documents/services/pdf_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Données communes famille Dupont / Sophie Martin
  final employeur = (
    nom: 'DUPONT',
    prenom: 'Marie',
    adresse: '12 rue des Roses',
    ville: 'Paris',
    cp: '75001',
    tel: '06 12 34 56 78',
    email: 'marie.dupont@email.com',
    pajemploi: '123456789',
  );
  final salarie = (
    nom: 'MARTIN',
    prenom: 'Sophie',
    adresse: '5 avenue Victor Hugo',
    ville: 'Lyon',
    cp: '69001',
    tel: '06 45 67 89 01',
    email: 'sophie.martin@email.com',
    secu: '2 85 06 69 123 456 78',
    agrement: 'AGR-2021-69-001234',
    dateAgrement: DateTime(2021, 3, 15),
    dateRenouvellement: DateTime(2026, 3, 14),
    rcPro: 'MAIF',
    rcProPolice: 'RC-PRO-2024-789012',
    auto: 'AXA',
    autoPolice: 'AUTO-AXA-456789',
  );

  test('Generation CDI', () async {
    final model = ContratCdiModel(
      // Employeur
      nomNaissanceEmployeur: employeur.nom,
      nomUsageEmployeur: employeur.nom,
      prenomEmployeur: employeur.prenom,
      adresseEmployeur: employeur.adresse,
      villeEmployeur: employeur.ville,
      codePostalEmployeur: employeur.cp,
      telephoneEmployeur: employeur.tel,
      emailEmployeur: employeur.email,
      qualiteEmployeur: QualiteCdiEmployeur.mere,
      numeroPajemploi: employeur.pajemploi,
      telephoneParent2: '06 98 76 54 32',
      emailParent2: 'paul.dupont@email.com',

      // Salarie
      nomNaissanceSalarie: salarie.nom,
      nomUsageSalarie: salarie.nom,
      prenomSalarie: salarie.prenom,
      adresseSalarie: salarie.adresse,
      villeSalarie: salarie.ville,
      codePostalSalarie: salarie.cp,
      telephoneSalarie: salarie.tel,
      emailSalarie: salarie.email,
      numeroSecu: salarie.secu,
      referenceAgrement: salarie.agrement,
      dateLivraisonAgrement: salarie.dateAgrement,
      dateRenouvellementAgrement: salarie.dateRenouvellement,
      assuranceRCProNom: salarie.rcPro,
      assuranceRCProPolice: salarie.rcProPolice,
      assuranceAutoNom: salarie.auto,
      assuranceAutoPolice: salarie.autoPolice,

      // Lieu
      lieuTravailType: LieuTravailType.domicileSalarie,
      lieuTravailAdresse: '5 avenue Victor Hugo, 69001 Lyon',

      // Enfant
      nomEnfant: 'DUPONT',
      prenomEnfant: 'Emma',
      dateNaissanceEnfant: DateTime(2022, 3, 15),
      dateEmbauche: DateTime(2024, 9, 1),

      // Periode essai/adaptation
      dureePeriodeEssai: '3 mois',
      dureePeriodeAdaptationJours: 15,
      dateDebutAdaptation: DateTime(2024, 9, 1),
      dateFinAdaptation: DateTime(2024, 9, 15),
      notesAdaptation: "L'enfant sera accompagee de sa mere les 3 premiers jours.",

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

      // Remuneration
      salaireHoraireBrut: 3.80,
      salaireHoraireNet: 2.97,
      salaireHoraireMajoreBrut: 4.18,
      salaireHoraireMajoreNet: 3.27,
      tauxMajorationHeuresMajorees: 10.0,
      salaireHoraireMajoreesBrut: 4.18,
      salaireHorairesMajoreesNet: 3.27,
      salaireMensuelBrut: 580.40,
      salaireMensuelNet: 453.46,
      nbHeuresJourneeIndemniteEntretien: 10.0,
      montantHoraireIndemniteEntretien: 0.39,
      repasParSalarie: true,
      montantRepasSalarie: 3.00,
      indemnitesKmParKm: 0.41,
      jourPaiementSalaire: 5,

      // Repos
      jourReposHebdomadaire: 'Dimanche',
      travailReposMajore: false,

      // Jours feries
      premierMaiChome: true,
      joursFeriesOrdTravailles: ['Lundi de Paques', '8 mai', 'Jeudi de l\'Ascension', '14 juillet'],
      tauxMajorationJoursFeries: 10.0,

      // Conges
      modeVersementCP: ModeVersementCP.enJuin,

      // Conditions
      conditionsParticulieres:
          "L'enfant suit un regime sans gluten. Aucun aliment contenant du gluten ne devra lui etre donne.",

      // Signatures
      lieuSignature: 'Paris',
      dateSignature: DateTime(2024, 8, 28),
      luEtApprouveEmployeur: 'Lu et approuve',
      luEtApproveSalarie: 'Lu et approuve',
      luEtApprouveParent2: 'Lu et approuve',
    );

    final bytes = await ContratCdiPdfService().genererPdf(model);
    final file = File('/tmp/test_cdi.pdf');
    await file.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(5000));
    print('\nCDI genere : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });

  test('Generation CDD', () async {
    final model = ContratCddModel(
      // Employeur
      nomNaissanceEmployeur: employeur.nom,
      nomUsageEmployeur: employeur.nom,
      prenomEmployeur: employeur.prenom,
      adresseEmployeur: employeur.adresse,
      villeEmployeur: employeur.ville,
      codePostalEmployeur: employeur.cp,
      telephoneEmployeur: employeur.tel,
      emailEmployeur: employeur.email,
      qualiteEmployeur: QualiteCddEmployeur.mere,
      numeroPajemploi: employeur.pajemploi,
      telephoneParent2: '06 98 76 54 32',
      emailParent2: 'paul.dupont@email.com',
      luEtApprouveParent2: 'Lu et approuve',

      // Salarie
      nomNaissanceSalarie: salarie.nom,
      nomUsageSalarie: salarie.nom,
      prenomSalarie: salarie.prenom,
      adresseSalarie: salarie.adresse,
      villeSalarie: salarie.ville,
      codePostalSalarie: salarie.cp,
      telephoneSalarie: salarie.tel,
      emailSalarie: salarie.email,
      numeroSecu: salarie.secu,
      referenceAgrement: salarie.agrement,
      dateLivraisonAgrement: salarie.dateAgrement,
      dateRenouvellementAgrement: salarie.dateRenouvellement,
      assuranceRCProNom: salarie.rcPro,
      assuranceRCProPolice: salarie.rcProPolice,
      assuranceAutoNom: salarie.auto,
      assuranceAutoPolice: salarie.autoPolice,

      // Lieu
      lieuTravailType: LieuTravailTypeCdd.domicileSalarie,
      lieuTravailAdresse: '5 avenue Victor Hugo, 69001 Lyon',

      // Enfant
      nomEnfant: 'DUPONT',
      prenomEnfant: 'Emma',
      dateNaissanceEnfant: DateTime(2022, 3, 15),

      // Motif CDD
      motifCdd: "Accueil temporaire de l'enfant pendant le conge maternite de la mere",
      personneRemplaceeNom: 'Sophie MARTIN',

      // Duree
      typeDureeCdd: TypeDureeCdd.datesFixes,
      dateDebutContrat: DateTime(2024, 9, 1),
      dateFinContrat: DateTime(2025, 8, 31),

      // Periode essai/adaptation
      dureePeriodeEssai: '1 mois',
      dureePeriodeAdaptationJours: 15,
      dateDebutAdaptation: DateTime(2024, 9, 1),
      dateFinAdaptation: DateTime(2024, 9, 15),
      notesAdaptation: "L'enfant sera accompagee de sa mere les 3 premiers jours.",

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

      // Remuneration
      salaireHoraireBrut: 3.80,
      salaireHoraireNet: 2.97,
      salaireHoraireMajoreBrut: 4.18,
      salaireHoraireMajoreNet: 3.27,
      tauxMajorationHeuresMajorees: 10.0,
      salaireHoraireMajoreesBrut: 4.18,
      salaireHorairesMajoreesNet: 3.27,
      salaireMensuelBrut: 580.40,
      salaireMensuelNet: 453.46,
      nbHeuresJourneeIndemniteEntretien: 10.0,
      montantHoraireIndemniteEntretien: 0.39,
      repasParSalarie: true,
      montantRepasSalarie: 3.00,
      indemnitesKmParKm: 0.41,
      jourPaiementSalaire: 5,

      // Repos
      jourReposHebdomadaire: 'Dimanche',
      travailReposMajore: false,

      // Jours feries
      premierMaiChome: true,
      joursFeriesOrdTravailles: ['Lundi de Paques', '8 mai', 'Jeudi de l\'Ascension', '14 juillet'],
      tauxMajorationJoursFeries: 10.0,

      // Conditions
      conditionsParticulieres:
          "L'enfant suit un regime sans gluten. En cas de maladie, les parents seront contactes dans l'heure.",

      // Signatures
      lieuSignature: 'Paris',
      dateSignature: DateTime(2024, 8, 28),
      luEtApprouveEmployeur: 'Lu et approuve',
      luEtApproveSalarie: 'Lu et approuve',
    );

    final bytes = await ContratCddPdfService().genererPdf(model);
    final file = File('/tmp/test_cdd.pdf');
    await file.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(5000));
    print('\nCDD genere : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });

  test('Generation Avenant', () async {
    final model = AvenantModel(
      // Contrat original
      typeContratOriginal: TypeContratOriginal.cdi,
      dateContratOriginal: DateTime(2023, 1, 15),
      nomEnfant: 'DUPONT',
      prenomEnfant: 'Emma',

      // Employeur
      nomNaissanceEmployeur: employeur.nom,
      nomUsageEmployeur: employeur.nom,
      prenomEmployeur: employeur.prenom,
      adresseEmployeur: employeur.adresse,
      villeEmployeur: employeur.ville,
      codePostalEmployeur: employeur.cp,
      numeroPajemploi: employeur.pajemploi,

      // Salarie
      nomNaissanceSalarie: salarie.nom,
      nomUsageSalarie: salarie.nom,
      prenomSalarie: salarie.prenom,
      adresseSalarie: salarie.adresse,
      villeSalarie: salarie.ville,
      codePostalSalarie: salarie.cp,
      numeroSecu: salarie.secu,

      // Modifications
      modificationsTexte:
          "Modification des horaires de travail a compter du 01/09/2024. "
          "Les nouvelles heures hebdomadaires sont fixees a 45 heures. "
          "Le salaire mensuel brut est ajuste en consequence a 612,00 euros.",
      dateExecution: DateTime(2024, 9, 1),

      // Signatures
      lieuSignature: 'Paris',
      dateSignature: DateTime(2024, 8, 25),
      luEtApprouveEmployeur: 'Lu et approuve',
      luEtApproveSalarie: 'Lu et approuve',
    );

    final bytes = await AvenantPdfService().genererPdf(model);
    final file = File('/tmp/test_avenant.pdf');
    await file.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(5000));
    print('\nAvenant genere : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });

  test('Generation Engagement Reciproque', () async {
    final model = EngagementReciproqueModel(
      // Employeur
      civiliteEmployeur: Civilite.mme,
      nomEmployeur: employeur.nom,
      prenomEmployeur: employeur.prenom,
      adresseEmployeur: employeur.adresse,
      villeEmployeur: employeur.ville,
      codePostalEmployeur: employeur.cp,
      qualiteEmployeur: QualiteEmployeur.mere,
      telephoneEmployeur: employeur.tel,
      emailEmployeur: employeur.email,

      // Salarie
      civiliteSalarie: Civilite.mme,
      nomSalarie: salarie.nom,
      prenomSalarie: salarie.prenom,
      adresseSalarie: salarie.adresse,
      villeSalarie: salarie.ville,
      codePostalSalarie: salarie.cp,
      telephoneSalarie: salarie.tel,
      emailSalarie: salarie.email,

      // Enfant & contrat
      nomEnfant: 'Emma DUPONT',
      dateDebutContrat: DateTime(2024, 9, 1),

      // Conditions d'accueil
      heuresParSemaine: 40.0,
      heuresParMois: 173.33,
      semainesParAn: 46,

      // Remuneration
      salaireMensuelBrut: 580.40,
      salaireHoraireBrut: 3.80,

      // Signatures
      lieuSignature: 'Paris',
      dateSignature: DateTime(2024, 8, 28),
      // Pas de signature image en test — le PDF doit gerer gracieusement null
    );

    final bytes = await PdfGeneratorService().genererEngagementPdf(model);
    final file = File('/tmp/test_engagement.pdf');
    await file.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(5000));
    print('\nEngagement genere : ${file.path} (${(bytes.length / 1024).toStringAsFixed(1)} Ko)');
  });
}
