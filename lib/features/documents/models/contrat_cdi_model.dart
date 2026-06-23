import 'dart:convert';
import 'dart:typed_data';

class _Absent {
  const _Absent();
}

const _absent = _Absent();

// ─── Enums ────────────────────────────────────────────────────────────────────

enum QualiteCdiEmployeur { pere, mere, tuteur, autre }

extension QualiteCdiEmployeurLabel on QualiteCdiEmployeur {
  String get label {
    switch (this) {
      case QualiteCdiEmployeur.pere:
        return 'Père';
      case QualiteCdiEmployeur.mere:
        return 'Mère';
      case QualiteCdiEmployeur.tuteur:
        return 'Tuteur';
      case QualiteCdiEmployeur.autre:
        return 'Autre';
    }
  }
}

enum TypeAccueilCdi { cas1_52semaines, cas2_46semaines }

extension TypeAccueilCdiLabel on TypeAccueilCdi {
  String get label {
    switch (this) {
      case TypeAccueilCdi.cas1_52semaines:
        return '52 semaines (y compris congés)';
      case TypeAccueilCdi.cas2_46semaines:
        return '46 semaines ou moins (hors congés)';
    }
  }
}

enum LieuTravailType { domicileSalarie, maisonAma }

enum ModeVersementCP { enJuin, prisePrincipale, furetAMesure }

extension ModeVersementCPLabel on ModeVersementCP {
  String get label {
    switch (this) {
      case ModeVersementCP.enJuin:
        return 'En une seule fois au mois de juin';
      case ModeVersementCP.prisePrincipale:
        return 'Lors de la prise principale des congés';
      case ModeVersementCP.furetAMesure:
        return 'Au fur et à mesure de la prise des congés';
    }
  }
}

// ─── Planning ligne ───────────────────────────────────────────────────────────

class LignePlanning {
  String jourTravail;
  String horairesTravail;
  String nbHeuresTravail;

  LignePlanning({
    this.jourTravail = '',
    this.horairesTravail = '',
    this.nbHeuresTravail = '',
  });

  Map<String, dynamic> toJson() => {
        'jourTravail': jourTravail,
        'horairesTravail': horairesTravail,
        'nbHeuresTravail': nbHeuresTravail,
      };

  factory LignePlanning.fromJson(Map<String, dynamic> json) => LignePlanning(
        jourTravail: (json['jourTravail'] as String?) ?? '',
        horairesTravail: (json['horairesTravail'] as String?) ?? '',
        nbHeuresTravail: (json['nbHeuresTravail'] as String?) ?? '',
      );

  LignePlanning copyWith({
    String? jourTravail,
    String? horairesTravail,
    String? nbHeuresTravail,
  }) =>
      LignePlanning(
        jourTravail: jourTravail ?? this.jourTravail,
        horairesTravail: horairesTravail ?? this.horairesTravail,
        nbHeuresTravail: nbHeuresTravail ?? this.nbHeuresTravail,
      );
}

// ─── Modèle principal ─────────────────────────────────────────────────────────

class ContratCdiModel {
  // ── Employeur (parent) ────────────────────────────────────────────────────
  String? nomNaissanceEmployeur;
  String? nomUsageEmployeur;
  String? prenomEmployeur;
  String? adresseEmployeur;
  String? villeEmployeur;
  String? codePostalEmployeur;
  String? telephoneEmployeur;
  String? emailEmployeur;
  QualiteCdiEmployeur? qualiteEmployeur;
  String? numeroPajemploi;
  String? telephoneParent2;
  String? emailParent2;

  // ── Salarié (assistante maternelle) ───────────────────────────────────────
  String? nomNaissanceSalarie;
  String? nomUsageSalarie;
  String? prenomSalarie;
  String? adresseSalarie;
  String? villeSalarie;
  String? codePostalSalarie;
  String? telephoneSalarie;
  String? emailSalarie;
  String? numeroSecu;
  String? referenceAgrement;
  DateTime? dateLivraisonAgrement;
  DateTime? dateRenouvellementAgrement;
  String? assuranceRCProNom;
  String? assuranceRCProPolice;
  String? assuranceAutoNom;
  String? assuranceAutoPolice;

  // ── Lieu de travail ───────────────────────────────────────────────────────
  LieuTravailType? lieuTravailType;
  String? lieuTravailAdresse;

  // ── Enfant & date d'effet ─────────────────────────────────────────────────
  String? nomEnfant;
  String? prenomEnfant;
  DateTime? dateNaissanceEnfant;
  DateTime? dateEmbauche;
  String? dureePeriodeEssai;
  int? dureePeriodeAdaptationJours;
  DateTime? dateDebutAdaptation;
  DateTime? dateFinAdaptation;
  String? notesAdaptation;

  // ── Horaires (Article 4) ──────────────────────────────────────────────────
  TypeAccueilCdi? typeAccueil;
  double? heuresParSemaine;
  List<LignePlanning> lignesPlanning;
  int? delaiPrevenanceSemaines;
  int? nombreSemainesGarde;
  bool planningParEcrit;
  int? delaiPrevenancePlanningEcrit;

  // ── Rémunération (Article 5) ──────────────────────────────────────────────
  double? salaireHoraireBrut;
  double? salaireHoraireNet;
  double? salaireHoraireMajoreBrut;
  double? salaireHoraireMajoreNet;
  double? tauxMajorationHeuresMajorees;
  double? salaireHoraireMajoreesBrut;
  double? salaireHorairesMajoreesNet;
  double? salaireMensuelBrut;
  double? salaireMensuelNet;
  double? nbHeuresJourneeIndemniteEntretien;
  double? montantHoraireIndemniteEntretien;
  bool repasParEmployeur;
  bool repasParSalarie;
  double? montantRepasEmployeur;
  double? montantRepasSalarie;
  double? indemnitesKmParKm;
  int? jourPaiementSalaire;
  bool accordPajemploiPlus;

  // ── Repos hebdomadaire (Article 6) ───────────────────────────────────────
  String? jourReposHebdomadaire;
  bool travailReposMajore;
  bool travailReposRecupere;

  // ── Jours fériés (Article 7) ──────────────────────────────────────────────
  bool premierMaiChome;
  List<String> joursFeriesOrdTravailles;
  double? tauxMajorationJoursFeries;

  // ── Congés (Article 8) ────────────────────────────────────────────────────
  ModeVersementCP? modeVersementCP;

  // ── Conditions particulières (Article 10) ────────────────────────────────
  String? conditionsParticulieres;

  // ── Signatures ────────────────────────────────────────────────────────────
  String? lieuSignature;
  DateTime? dateSignature;
  String? luEtApprouveEmployeur;
  String? luEtApproveSalarie;
  String? luEtApprouveParent2;
  Uint8List? signatureEmployeur;
  Uint8List? signatureSalarie;
  Uint8List? signatureParent2;

  ContratCdiModel({
    this.nomNaissanceEmployeur,
    this.nomUsageEmployeur,
    this.prenomEmployeur,
    this.adresseEmployeur,
    this.villeEmployeur,
    this.codePostalEmployeur,
    this.telephoneEmployeur,
    this.emailEmployeur,
    this.qualiteEmployeur,
    this.numeroPajemploi,
    this.telephoneParent2,
    this.emailParent2,
    this.nomNaissanceSalarie,
    this.nomUsageSalarie,
    this.prenomSalarie,
    this.adresseSalarie,
    this.villeSalarie,
    this.codePostalSalarie,
    this.telephoneSalarie,
    this.emailSalarie,
    this.numeroSecu,
    this.referenceAgrement,
    this.dateLivraisonAgrement,
    this.dateRenouvellementAgrement,
    this.assuranceRCProNom,
    this.assuranceRCProPolice,
    this.assuranceAutoNom,
    this.assuranceAutoPolice,
    this.lieuTravailType,
    this.lieuTravailAdresse,
    this.nomEnfant,
    this.prenomEnfant,
    this.dateNaissanceEnfant,
    this.dateEmbauche,
    this.dureePeriodeEssai,
    this.dureePeriodeAdaptationJours,
    this.dateDebutAdaptation,
    this.dateFinAdaptation,
    this.notesAdaptation,
    this.typeAccueil,
    this.heuresParSemaine,
    List<LignePlanning>? lignesPlanning,
    this.delaiPrevenanceSemaines,
    this.nombreSemainesGarde,
    this.planningParEcrit = false,
    this.delaiPrevenancePlanningEcrit,
    this.salaireHoraireBrut,
    this.salaireHoraireNet,
    this.salaireHoraireMajoreBrut,
    this.salaireHoraireMajoreNet,
    this.tauxMajorationHeuresMajorees,
    this.salaireHoraireMajoreesBrut,
    this.salaireHorairesMajoreesNet,
    this.salaireMensuelBrut,
    this.salaireMensuelNet,
    this.nbHeuresJourneeIndemniteEntretien,
    this.montantHoraireIndemniteEntretien,
    this.repasParEmployeur = false,
    this.repasParSalarie = false,
    this.montantRepasEmployeur,
    this.montantRepasSalarie,
    this.indemnitesKmParKm,
    this.jourPaiementSalaire,
    this.accordPajemploiPlus = false,
    this.jourReposHebdomadaire,
    this.travailReposMajore = false,
    this.travailReposRecupere = false,
    this.premierMaiChome = true,
    List<String>? joursFeriesOrdTravailles,
    this.tauxMajorationJoursFeries,
    this.modeVersementCP,
    this.conditionsParticulieres,
    this.lieuSignature,
    this.dateSignature,
    this.luEtApprouveEmployeur,
    this.luEtApproveSalarie,
    this.luEtApprouveParent2,
    this.signatureEmployeur,
    this.signatureSalarie,
    this.signatureParent2,
  })  : lignesPlanning = lignesPlanning ?? [LignePlanning()],
        joursFeriesOrdTravailles = joursFeriesOrdTravailles ?? [];

  // ─── Sérialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'nomNaissanceEmployeur': nomNaissanceEmployeur,
      'nomUsageEmployeur': nomUsageEmployeur,
      'prenomEmployeur': prenomEmployeur,
      'adresseEmployeur': adresseEmployeur,
      'villeEmployeur': villeEmployeur,
      'codePostalEmployeur': codePostalEmployeur,
      'telephoneEmployeur': telephoneEmployeur,
      'emailEmployeur': emailEmployeur,
      'qualiteEmployeur': qualiteEmployeur?.name,
      'numeroPajemploi': numeroPajemploi,
      'telephoneParent2': telephoneParent2,
      'emailParent2': emailParent2,
      'nomNaissanceSalarie': nomNaissanceSalarie,
      'nomUsageSalarie': nomUsageSalarie,
      'prenomSalarie': prenomSalarie,
      'adresseSalarie': adresseSalarie,
      'villeSalarie': villeSalarie,
      'codePostalSalarie': codePostalSalarie,
      'telephoneSalarie': telephoneSalarie,
      'emailSalarie': emailSalarie,
      'numeroSecu': numeroSecu,
      'referenceAgrement': referenceAgrement,
      'dateLivraisonAgrement': dateLivraisonAgrement?.toIso8601String(),
      'dateRenouvellementAgrement': dateRenouvellementAgrement?.toIso8601String(),
      'assuranceRCProNom': assuranceRCProNom,
      'assuranceRCProPolice': assuranceRCProPolice,
      'assuranceAutoNom': assuranceAutoNom,
      'assuranceAutoPolice': assuranceAutoPolice,
      'lieuTravailType': lieuTravailType?.name,
      'lieuTravailAdresse': lieuTravailAdresse,
      'nomEnfant': nomEnfant,
      'prenomEnfant': prenomEnfant,
      'dateNaissanceEnfant': dateNaissanceEnfant?.toIso8601String(),
      'dateEmbauche': dateEmbauche?.toIso8601String(),
      'dureePeriodeEssai': dureePeriodeEssai,
      'dureePeriodeAdaptationJours': dureePeriodeAdaptationJours,
      'dateDebutAdaptation': dateDebutAdaptation?.toIso8601String(),
      'dateFinAdaptation': dateFinAdaptation?.toIso8601String(),
      'notesAdaptation': notesAdaptation,
      'typeAccueil': typeAccueil?.name,
      'heuresParSemaine': heuresParSemaine,
      'lignesPlanning': lignesPlanning.map((l) => l.toJson()).toList(),
      'delaiPrevenanceSemaines': delaiPrevenanceSemaines,
      'nombreSemainesGarde': nombreSemainesGarde,
      'planningParEcrit': planningParEcrit,
      'delaiPrevenancePlanningEcrit': delaiPrevenancePlanningEcrit,
      'salaireHoraireBrut': salaireHoraireBrut,
      'salaireHoraireNet': salaireHoraireNet,
      'salaireHoraireMajoreBrut': salaireHoraireMajoreBrut,
      'salaireHoraireMajoreNet': salaireHoraireMajoreNet,
      'tauxMajorationHeuresMajorees': tauxMajorationHeuresMajorees,
      'salaireHoraireMajoreesBrut': salaireHoraireMajoreesBrut,
      'salaireHorairesMajoreesNet': salaireHorairesMajoreesNet,
      'salaireMensuelBrut': salaireMensuelBrut,
      'salaireMensuelNet': salaireMensuelNet,
      'nbHeuresJourneeIndemniteEntretien': nbHeuresJourneeIndemniteEntretien,
      'montantHoraireIndemniteEntretien': montantHoraireIndemniteEntretien,
      'repasParEmployeur': repasParEmployeur,
      'repasParSalarie': repasParSalarie,
      'montantRepasEmployeur': montantRepasEmployeur,
      'montantRepasSalarie': montantRepasSalarie,
      'indemnitesKmParKm': indemnitesKmParKm,
      'jourPaiementSalaire': jourPaiementSalaire,
      'accordPajemploiPlus': accordPajemploiPlus,
      'jourReposHebdomadaire': jourReposHebdomadaire,
      'travailReposMajore': travailReposMajore,
      'travailReposRecupere': travailReposRecupere,
      'premierMaiChome': premierMaiChome,
      'joursFeriesOrdTravailles': joursFeriesOrdTravailles,
      'tauxMajorationJoursFeries': tauxMajorationJoursFeries,
      'modeVersementCP': modeVersementCP?.name,
      'conditionsParticulieres': conditionsParticulieres,
      'lieuSignature': lieuSignature,
      'dateSignature': dateSignature?.toIso8601String(),
      'luEtApprouveEmployeur': luEtApprouveEmployeur,
      'luEtApproveSalarie': luEtApproveSalarie,
      'luEtApprouveParent2': luEtApprouveParent2,
      'signatureEmployeur': signatureEmployeur != null ? base64Encode(signatureEmployeur!) : null,
      'signatureSalarie': signatureSalarie != null ? base64Encode(signatureSalarie!) : null,
      'signatureParent2': signatureParent2 != null ? base64Encode(signatureParent2!) : null,
    };
  }

  factory ContratCdiModel.fromJson(Map<String, dynamic> json) {
    return ContratCdiModel(
      nomNaissanceEmployeur: json['nomNaissanceEmployeur'] as String?,
      nomUsageEmployeur: json['nomUsageEmployeur'] as String?,
      prenomEmployeur: json['prenomEmployeur'] as String?,
      adresseEmployeur: json['adresseEmployeur'] as String?,
      villeEmployeur: json['villeEmployeur'] as String?,
      codePostalEmployeur: json['codePostalEmployeur'] as String?,
      telephoneEmployeur: json['telephoneEmployeur'] as String?,
      emailEmployeur: json['emailEmployeur'] as String?,
      qualiteEmployeur: json['qualiteEmployeur'] != null
          ? QualiteCdiEmployeur.values.firstWhere(
              (e) => e.name == json['qualiteEmployeur'],
              orElse: () => QualiteCdiEmployeur.autre,
            )
          : null,
      numeroPajemploi: json['numeroPajemploi'] as String?,
      telephoneParent2: json['telephoneParent2'] as String?,
      emailParent2: json['emailParent2'] as String?,
      nomNaissanceSalarie: json['nomNaissanceSalarie'] as String?,
      nomUsageSalarie: json['nomUsageSalarie'] as String?,
      prenomSalarie: json['prenomSalarie'] as String?,
      adresseSalarie: json['adresseSalarie'] as String?,
      villeSalarie: json['villeSalarie'] as String?,
      codePostalSalarie: json['codePostalSalarie'] as String?,
      telephoneSalarie: json['telephoneSalarie'] as String?,
      emailSalarie: json['emailSalarie'] as String?,
      numeroSecu: json['numeroSecu'] as String?,
      referenceAgrement: json['referenceAgrement'] as String?,
      dateLivraisonAgrement: json['dateLivraisonAgrement'] != null
          ? DateTime.tryParse(json['dateLivraisonAgrement'] as String)
          : null,
      dateRenouvellementAgrement: json['dateRenouvellementAgrement'] != null
          ? DateTime.tryParse(json['dateRenouvellementAgrement'] as String)
          : null,
      assuranceRCProNom: json['assuranceRCProNom'] as String?,
      assuranceRCProPolice: json['assuranceRCProPolice'] as String?,
      assuranceAutoNom: json['assuranceAutoNom'] as String?,
      assuranceAutoPolice: json['assuranceAutoPolice'] as String?,
      lieuTravailType: json['lieuTravailType'] != null
          ? LieuTravailType.values.firstWhere(
              (e) => e.name == json['lieuTravailType'],
              orElse: () => LieuTravailType.domicileSalarie,
            )
          : null,
      lieuTravailAdresse: json['lieuTravailAdresse'] as String?,
      nomEnfant: json['nomEnfant'] as String?,
      prenomEnfant: json['prenomEnfant'] as String?,
      dateNaissanceEnfant: json['dateNaissanceEnfant'] != null
          ? DateTime.tryParse(json['dateNaissanceEnfant'] as String)
          : null,
      dateEmbauche: json['dateEmbauche'] != null
          ? DateTime.tryParse(json['dateEmbauche'] as String)
          : null,
      dureePeriodeEssai: json['dureePeriodeEssai'] as String?,
      dureePeriodeAdaptationJours: (json['dureePeriodeAdaptationJours'] as num?)?.toInt(),
      dateDebutAdaptation: json['dateDebutAdaptation'] != null
          ? DateTime.tryParse(json['dateDebutAdaptation'] as String)
          : null,
      dateFinAdaptation: json['dateFinAdaptation'] != null
          ? DateTime.tryParse(json['dateFinAdaptation'] as String)
          : null,
      notesAdaptation: json['notesAdaptation'] as String?,
      typeAccueil: json['typeAccueil'] != null
          ? TypeAccueilCdi.values.firstWhere(
              (e) => e.name == json['typeAccueil'],
              orElse: () => TypeAccueilCdi.cas1_52semaines,
            )
          : null,
      heuresParSemaine: (json['heuresParSemaine'] as num?)?.toDouble(),
      lignesPlanning: (json['lignesPlanning'] as List<dynamic>?)
              ?.map((e) => LignePlanning.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [LignePlanning()],
      delaiPrevenanceSemaines: (json['delaiPrevenanceSemaines'] as num?)?.toInt(),
      nombreSemainesGarde: (json['nombreSemainesGarde'] as num?)?.toInt(),
      planningParEcrit: (json['planningParEcrit'] as bool?) ?? false,
      delaiPrevenancePlanningEcrit: (json['delaiPrevenancePlanningEcrit'] as num?)?.toInt(),
      salaireHoraireBrut: (json['salaireHoraireBrut'] as num?)?.toDouble(),
      salaireHoraireNet: (json['salaireHoraireNet'] as num?)?.toDouble(),
      salaireHoraireMajoreBrut: (json['salaireHoraireMajoreBrut'] as num?)?.toDouble(),
      salaireHoraireMajoreNet: (json['salaireHoraireMajoreNet'] as num?)?.toDouble(),
      tauxMajorationHeuresMajorees: (json['tauxMajorationHeuresMajorees'] as num?)?.toDouble(),
      salaireHoraireMajoreesBrut: (json['salaireHoraireMajoreesBrut'] as num?)?.toDouble(),
      salaireHorairesMajoreesNet: (json['salaireHorairesMajoreesNet'] as num?)?.toDouble(),
      salaireMensuelBrut: (json['salaireMensuelBrut'] as num?)?.toDouble(),
      salaireMensuelNet: (json['salaireMensuelNet'] as num?)?.toDouble(),
      nbHeuresJourneeIndemniteEntretien: (json['nbHeuresJourneeIndemniteEntretien'] as num?)?.toDouble(),
      montantHoraireIndemniteEntretien: (json['montantHoraireIndemniteEntretien'] as num?)?.toDouble(),
      repasParEmployeur: (json['repasParEmployeur'] as bool?) ?? false,
      repasParSalarie: (json['repasParSalarie'] as bool?) ?? false,
      montantRepasEmployeur: (json['montantRepasEmployeur'] as num?)?.toDouble(),
      montantRepasSalarie: (json['montantRepasSalarie'] as num?)?.toDouble(),
      indemnitesKmParKm: (json['indemnitesKmParKm'] as num?)?.toDouble(),
      jourPaiementSalaire: (json['jourPaiementSalaire'] as num?)?.toInt(),
      accordPajemploiPlus: (json['accordPajemploiPlus'] as bool?) ?? false,
      jourReposHebdomadaire: json['jourReposHebdomadaire'] as String?,
      travailReposMajore: (json['travailReposMajore'] as bool?) ?? false,
      travailReposRecupere: (json['travailReposRecupere'] as bool?) ?? false,
      premierMaiChome: (json['premierMaiChome'] as bool?) ?? true,
      joursFeriesOrdTravailles: (json['joursFeriesOrdTravailles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tauxMajorationJoursFeries: (json['tauxMajorationJoursFeries'] as num?)?.toDouble(),
      modeVersementCP: json['modeVersementCP'] != null
          ? ModeVersementCP.values.firstWhere(
              (e) => e.name == json['modeVersementCP'],
              orElse: () => ModeVersementCP.enJuin,
            )
          : null,
      conditionsParticulieres: json['conditionsParticulieres'] as String?,
      lieuSignature: json['lieuSignature'] as String?,
      dateSignature: json['dateSignature'] != null
          ? DateTime.tryParse(json['dateSignature'] as String)
          : null,
      luEtApprouveEmployeur: json['luEtApprouveEmployeur'] as String?,
      luEtApproveSalarie: json['luEtApproveSalarie'] as String?,
      luEtApprouveParent2: json['luEtApprouveParent2'] as String?,
      signatureEmployeur: json['signatureEmployeur'] != null
          ? base64Decode(json['signatureEmployeur'] as String)
          : null,
      signatureSalarie: json['signatureSalarie'] != null
          ? base64Decode(json['signatureSalarie'] as String)
          : null,
      signatureParent2: json['signatureParent2'] != null
          ? base64Decode(json['signatureParent2'] as String)
          : null,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  ContratCdiModel copyWith({
    String? nomNaissanceEmployeur,
    String? nomUsageEmployeur,
    String? prenomEmployeur,
    String? adresseEmployeur,
    String? villeEmployeur,
    String? codePostalEmployeur,
    String? telephoneEmployeur,
    String? emailEmployeur,
    QualiteCdiEmployeur? qualiteEmployeur,
    String? numeroPajemploi,
    String? telephoneParent2,
    String? emailParent2,
    String? nomNaissanceSalarie,
    String? nomUsageSalarie,
    String? prenomSalarie,
    String? adresseSalarie,
    String? villeSalarie,
    String? codePostalSalarie,
    String? telephoneSalarie,
    String? emailSalarie,
    String? numeroSecu,
    String? referenceAgrement,
    DateTime? dateLivraisonAgrement,
    DateTime? dateRenouvellementAgrement,
    String? assuranceRCProNom,
    String? assuranceRCProPolice,
    String? assuranceAutoNom,
    String? assuranceAutoPolice,
    LieuTravailType? lieuTravailType,
    String? lieuTravailAdresse,
    String? nomEnfant,
    String? prenomEnfant,
    DateTime? dateNaissanceEnfant,
    DateTime? dateEmbauche,
    String? dureePeriodeEssai,
    int? dureePeriodeAdaptationJours,
    DateTime? dateDebutAdaptation,
    DateTime? dateFinAdaptation,
    String? notesAdaptation,
    TypeAccueilCdi? typeAccueil,
    double? heuresParSemaine,
    List<LignePlanning>? lignesPlanning,
    int? delaiPrevenanceSemaines,
    int? nombreSemainesGarde,
    bool? planningParEcrit,
    int? delaiPrevenancePlanningEcrit,
    double? salaireHoraireBrut,
    double? salaireHoraireNet,
    double? salaireHoraireMajoreBrut,
    double? salaireHoraireMajoreNet,
    double? tauxMajorationHeuresMajorees,
    double? salaireHoraireMajoreesBrut,
    double? salaireHorairesMajoreesNet,
    double? salaireMensuelBrut,
    double? salaireMensuelNet,
    double? nbHeuresJourneeIndemniteEntretien,
    double? montantHoraireIndemniteEntretien,
    bool? repasParEmployeur,
    bool? repasParSalarie,
    double? montantRepasEmployeur,
    double? montantRepasSalarie,
    double? indemnitesKmParKm,
    int? jourPaiementSalaire,
    bool? accordPajemploiPlus,
    String? jourReposHebdomadaire,
    bool? travailReposMajore,
    bool? travailReposRecupere,
    bool? premierMaiChome,
    List<String>? joursFeriesOrdTravailles,
    double? tauxMajorationJoursFeries,
    ModeVersementCP? modeVersementCP,
    String? conditionsParticulieres,
    String? lieuSignature,
    DateTime? dateSignature,
    String? luEtApprouveEmployeur,
    String? luEtApproveSalarie,
    String? luEtApprouveParent2,
    Object? signatureEmployeur = _absent,
    Object? signatureSalarie = _absent,
    Object? signatureParent2 = _absent,
  }) {
    return ContratCdiModel(
      nomNaissanceEmployeur: nomNaissanceEmployeur ?? this.nomNaissanceEmployeur,
      nomUsageEmployeur: nomUsageEmployeur ?? this.nomUsageEmployeur,
      prenomEmployeur: prenomEmployeur ?? this.prenomEmployeur,
      adresseEmployeur: adresseEmployeur ?? this.adresseEmployeur,
      villeEmployeur: villeEmployeur ?? this.villeEmployeur,
      codePostalEmployeur: codePostalEmployeur ?? this.codePostalEmployeur,
      telephoneEmployeur: telephoneEmployeur ?? this.telephoneEmployeur,
      emailEmployeur: emailEmployeur ?? this.emailEmployeur,
      qualiteEmployeur: qualiteEmployeur ?? this.qualiteEmployeur,
      numeroPajemploi: numeroPajemploi ?? this.numeroPajemploi,
      telephoneParent2: telephoneParent2 ?? this.telephoneParent2,
      emailParent2: emailParent2 ?? this.emailParent2,
      nomNaissanceSalarie: nomNaissanceSalarie ?? this.nomNaissanceSalarie,
      nomUsageSalarie: nomUsageSalarie ?? this.nomUsageSalarie,
      prenomSalarie: prenomSalarie ?? this.prenomSalarie,
      adresseSalarie: adresseSalarie ?? this.adresseSalarie,
      villeSalarie: villeSalarie ?? this.villeSalarie,
      codePostalSalarie: codePostalSalarie ?? this.codePostalSalarie,
      telephoneSalarie: telephoneSalarie ?? this.telephoneSalarie,
      emailSalarie: emailSalarie ?? this.emailSalarie,
      numeroSecu: numeroSecu ?? this.numeroSecu,
      referenceAgrement: referenceAgrement ?? this.referenceAgrement,
      dateLivraisonAgrement: dateLivraisonAgrement ?? this.dateLivraisonAgrement,
      dateRenouvellementAgrement: dateRenouvellementAgrement ?? this.dateRenouvellementAgrement,
      assuranceRCProNom: assuranceRCProNom ?? this.assuranceRCProNom,
      assuranceRCProPolice: assuranceRCProPolice ?? this.assuranceRCProPolice,
      assuranceAutoNom: assuranceAutoNom ?? this.assuranceAutoNom,
      assuranceAutoPolice: assuranceAutoPolice ?? this.assuranceAutoPolice,
      lieuTravailType: lieuTravailType ?? this.lieuTravailType,
      lieuTravailAdresse: lieuTravailAdresse ?? this.lieuTravailAdresse,
      nomEnfant: nomEnfant ?? this.nomEnfant,
      prenomEnfant: prenomEnfant ?? this.prenomEnfant,
      dateNaissanceEnfant: dateNaissanceEnfant ?? this.dateNaissanceEnfant,
      dateEmbauche: dateEmbauche ?? this.dateEmbauche,
      dureePeriodeEssai: dureePeriodeEssai ?? this.dureePeriodeEssai,
      dureePeriodeAdaptationJours: dureePeriodeAdaptationJours ?? this.dureePeriodeAdaptationJours,
      dateDebutAdaptation: dateDebutAdaptation ?? this.dateDebutAdaptation,
      dateFinAdaptation: dateFinAdaptation ?? this.dateFinAdaptation,
      notesAdaptation: notesAdaptation ?? this.notesAdaptation,
      typeAccueil: typeAccueil ?? this.typeAccueil,
      heuresParSemaine: heuresParSemaine ?? this.heuresParSemaine,
      lignesPlanning: lignesPlanning ?? this.lignesPlanning,
      delaiPrevenanceSemaines: delaiPrevenanceSemaines ?? this.delaiPrevenanceSemaines,
      nombreSemainesGarde: nombreSemainesGarde ?? this.nombreSemainesGarde,
      planningParEcrit: planningParEcrit ?? this.planningParEcrit,
      delaiPrevenancePlanningEcrit: delaiPrevenancePlanningEcrit ?? this.delaiPrevenancePlanningEcrit,
      salaireHoraireBrut: salaireHoraireBrut ?? this.salaireHoraireBrut,
      salaireHoraireNet: salaireHoraireNet ?? this.salaireHoraireNet,
      salaireHoraireMajoreBrut: salaireHoraireMajoreBrut ?? this.salaireHoraireMajoreBrut,
      salaireHoraireMajoreNet: salaireHoraireMajoreNet ?? this.salaireHoraireMajoreNet,
      tauxMajorationHeuresMajorees: tauxMajorationHeuresMajorees ?? this.tauxMajorationHeuresMajorees,
      salaireHoraireMajoreesBrut: salaireHoraireMajoreesBrut ?? this.salaireHoraireMajoreesBrut,
      salaireHorairesMajoreesNet: salaireHorairesMajoreesNet ?? this.salaireHorairesMajoreesNet,
      salaireMensuelBrut: salaireMensuelBrut ?? this.salaireMensuelBrut,
      salaireMensuelNet: salaireMensuelNet ?? this.salaireMensuelNet,
      nbHeuresJourneeIndemniteEntretien: nbHeuresJourneeIndemniteEntretien ?? this.nbHeuresJourneeIndemniteEntretien,
      montantHoraireIndemniteEntretien: montantHoraireIndemniteEntretien ?? this.montantHoraireIndemniteEntretien,
      repasParEmployeur: repasParEmployeur ?? this.repasParEmployeur,
      repasParSalarie: repasParSalarie ?? this.repasParSalarie,
      montantRepasEmployeur: montantRepasEmployeur ?? this.montantRepasEmployeur,
      montantRepasSalarie: montantRepasSalarie ?? this.montantRepasSalarie,
      indemnitesKmParKm: indemnitesKmParKm ?? this.indemnitesKmParKm,
      jourPaiementSalaire: jourPaiementSalaire ?? this.jourPaiementSalaire,
      accordPajemploiPlus: accordPajemploiPlus ?? this.accordPajemploiPlus,
      jourReposHebdomadaire: jourReposHebdomadaire ?? this.jourReposHebdomadaire,
      travailReposMajore: travailReposMajore ?? this.travailReposMajore,
      travailReposRecupere: travailReposRecupere ?? this.travailReposRecupere,
      premierMaiChome: premierMaiChome ?? this.premierMaiChome,
      joursFeriesOrdTravailles: joursFeriesOrdTravailles ?? this.joursFeriesOrdTravailles,
      tauxMajorationJoursFeries: tauxMajorationJoursFeries ?? this.tauxMajorationJoursFeries,
      modeVersementCP: modeVersementCP ?? this.modeVersementCP,
      conditionsParticulieres: conditionsParticulieres ?? this.conditionsParticulieres,
      lieuSignature: lieuSignature ?? this.lieuSignature,
      dateSignature: dateSignature ?? this.dateSignature,
      luEtApprouveEmployeur: luEtApprouveEmployeur ?? this.luEtApprouveEmployeur,
      luEtApproveSalarie: luEtApproveSalarie ?? this.luEtApproveSalarie,
      luEtApprouveParent2: luEtApprouveParent2 ?? this.luEtApprouveParent2,
      signatureEmployeur: signatureEmployeur == _absent
          ? this.signatureEmployeur
          : signatureEmployeur as Uint8List?,
      signatureSalarie: signatureSalarie == _absent
          ? this.signatureSalarie
          : signatureSalarie as Uint8List?,
      signatureParent2: signatureParent2 == _absent
          ? this.signatureParent2
          : signatureParent2 as Uint8List?,
    );
  }
}
