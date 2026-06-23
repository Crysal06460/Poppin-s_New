import 'dart:convert';
import 'dart:typed_data';

class _Absent {
  const _Absent();
}

const _absent = _Absent();

// ─── Enums ────────────────────────────────────────────────────────────────────

enum QualiteCddEmployeur { pere, mere, tuteur, autre }

extension QualiteCddEmployeurLabel on QualiteCddEmployeur {
  String get label {
    switch (this) {
      case QualiteCddEmployeur.pere: return 'Père';
      case QualiteCddEmployeur.mere: return 'Mère';
      case QualiteCddEmployeur.tuteur: return 'Tuteur';
      case QualiteCddEmployeur.autre: return 'Autre';
    }
  }
}

enum LieuTravailTypeCdd { domicileSalarie, maisonAma }

enum TypeDureeCdd { datesFixes, dureeAbsence }

// ─── Planning ligne ───────────────────────────────────────────────────────────

class LignePlanningCdd {
  String jourTravail;
  String horairesTravail;
  String nbHeuresTravail;

  LignePlanningCdd({
    this.jourTravail = '',
    this.horairesTravail = '',
    this.nbHeuresTravail = '',
  });

  Map<String, dynamic> toJson() => {
        'jourTravail': jourTravail,
        'horairesTravail': horairesTravail,
        'nbHeuresTravail': nbHeuresTravail,
      };

  factory LignePlanningCdd.fromJson(Map<String, dynamic> json) => LignePlanningCdd(
        jourTravail: (json['jourTravail'] as String?) ?? '',
        horairesTravail: (json['horairesTravail'] as String?) ?? '',
        nbHeuresTravail: (json['nbHeuresTravail'] as String?) ?? '',
      );

  LignePlanningCdd copyWith({
    String? jourTravail,
    String? horairesTravail,
    String? nbHeuresTravail,
  }) =>
      LignePlanningCdd(
        jourTravail: jourTravail ?? this.jourTravail,
        horairesTravail: horairesTravail ?? this.horairesTravail,
        nbHeuresTravail: nbHeuresTravail ?? this.nbHeuresTravail,
      );
}

// ─── Modèle principal ─────────────────────────────────────────────────────────

class ContratCddModel {
  // ── Employeur (parent) ────────────────────────────────────────────────────
  String? nomNaissanceEmployeur;
  String? nomUsageEmployeur;
  String? prenomEmployeur;
  String? adresseEmployeur;
  String? villeEmployeur;
  String? codePostalEmployeur;
  String? telephoneEmployeur;
  String? emailEmployeur;
  QualiteCddEmployeur? qualiteEmployeur;
  String? numeroPajemploi;

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
  LieuTravailTypeCdd? lieuTravailType;
  String? lieuTravailAdresse;

  // ── Enfant ────────────────────────────────────────────────────────────────
  String? nomEnfant;
  String? prenomEnfant;
  DateTime? dateNaissanceEnfant;

  // ── Motif CDD (Article 1) ─────────────────────────────────────────────────
  String? motifCdd;
  String? personneRemplaceeNom;

  // ── Durée du contrat (Article 3) ──────────────────────────────────────────
  TypeDureeCdd? typeDureeCdd;
  DateTime? dateDebutContrat;
  DateTime? dateFinContrat;
  String? personneAbsenteNom;
  String? dureeMinimaale;

  // ── Période d'essai & adaptation ─────────────────────────────────────────
  String? dureePeriodeEssai;
  int? dureePeriodeAdaptationJours;
  DateTime? dateDebutAdaptation;
  DateTime? dateFinAdaptation;

  // ── Horaires (Article 4) ──────────────────────────────────────────────────
  int? nombreSemaines;
  double? heuresParSemaine;
  List<LignePlanningCdd> lignesPlanning;
  bool planningParEcrit;
  int? delaiPrevenanceSemaines;
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

  // ── Conditions particulières (Article 10) ────────────────────────────────
  String? conditionsParticulieres;

  // ── Parent 2 (facultatif) ─────────────────────────────────────────────────
  String? telephoneParent2;
  String? emailParent2;
  String? luEtApprouveParent2;
  Uint8List? signatureParent2;

  // ── Notes adaptation ──────────────────────────────────────────────────────
  String? notesAdaptation;

  // ── Signatures ────────────────────────────────────────────────────────────
  String? lieuSignature;
  DateTime? dateSignature;
  String? luEtApprouveEmployeur;
  String? luEtApproveSalarie;
  Uint8List? signatureEmployeur;
  Uint8List? signatureSalarie;

  ContratCddModel({
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
    this.motifCdd,
    this.personneRemplaceeNom,
    this.typeDureeCdd,
    this.dateDebutContrat,
    this.dateFinContrat,
    this.personneAbsenteNom,
    this.dureeMinimaale,
    this.dureePeriodeEssai,
    this.dureePeriodeAdaptationJours,
    this.dateDebutAdaptation,
    this.dateFinAdaptation,
    this.nombreSemaines,
    this.heuresParSemaine,
    List<LignePlanningCdd>? lignesPlanning,
    this.planningParEcrit = false,
    this.delaiPrevenanceSemaines,
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
    this.conditionsParticulieres,
    this.telephoneParent2,
    this.emailParent2,
    this.luEtApprouveParent2,
    this.signatureParent2,
    this.notesAdaptation,
    this.lieuSignature,
    this.dateSignature,
    this.luEtApprouveEmployeur,
    this.luEtApproveSalarie,
    this.signatureEmployeur,
    this.signatureSalarie,
  })  : lignesPlanning = lignesPlanning ?? [LignePlanningCdd()],
        joursFeriesOrdTravailles = joursFeriesOrdTravailles ?? [];

  // ─── Sérialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
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
        'motifCdd': motifCdd,
        'personneRemplaceeNom': personneRemplaceeNom,
        'typeDureeCdd': typeDureeCdd?.name,
        'dateDebutContrat': dateDebutContrat?.toIso8601String(),
        'dateFinContrat': dateFinContrat?.toIso8601String(),
        'personneAbsenteNom': personneAbsenteNom,
        'dureeMinimaale': dureeMinimaale,
        'dureePeriodeEssai': dureePeriodeEssai,
        'dureePeriodeAdaptationJours': dureePeriodeAdaptationJours,
        'dateDebutAdaptation': dateDebutAdaptation?.toIso8601String(),
        'dateFinAdaptation': dateFinAdaptation?.toIso8601String(),
        'nombreSemaines': nombreSemaines,
        'heuresParSemaine': heuresParSemaine,
        'lignesPlanning': lignesPlanning.map((l) => l.toJson()).toList(),
        'planningParEcrit': planningParEcrit,
        'delaiPrevenanceSemaines': delaiPrevenanceSemaines,
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
        'conditionsParticulieres': conditionsParticulieres,
        'telephoneParent2': telephoneParent2,
        'emailParent2': emailParent2,
        'luEtApprouveParent2': luEtApprouveParent2,
        'signatureParent2': signatureParent2 != null ? base64Encode(signatureParent2!) : null,
        'notesAdaptation': notesAdaptation,
        'lieuSignature': lieuSignature,
        'dateSignature': dateSignature?.toIso8601String(),
        'luEtApprouveEmployeur': luEtApprouveEmployeur,
        'luEtApproveSalarie': luEtApproveSalarie,
        'signatureEmployeur': signatureEmployeur != null ? base64Encode(signatureEmployeur!) : null,
        'signatureSalarie': signatureSalarie != null ? base64Encode(signatureSalarie!) : null,
      };

  factory ContratCddModel.fromJson(Map<String, dynamic> json) {
    return ContratCddModel(
      nomNaissanceEmployeur: json['nomNaissanceEmployeur'] as String?,
      nomUsageEmployeur: json['nomUsageEmployeur'] as String?,
      prenomEmployeur: json['prenomEmployeur'] as String?,
      adresseEmployeur: json['adresseEmployeur'] as String?,
      villeEmployeur: json['villeEmployeur'] as String?,
      codePostalEmployeur: json['codePostalEmployeur'] as String?,
      telephoneEmployeur: json['telephoneEmployeur'] as String?,
      emailEmployeur: json['emailEmployeur'] as String?,
      qualiteEmployeur: json['qualiteEmployeur'] != null
          ? QualiteCddEmployeur.values.firstWhere((e) => e.name == json['qualiteEmployeur'], orElse: () => QualiteCddEmployeur.autre)
          : null,
      numeroPajemploi: json['numeroPajemploi'] as String?,
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
      dateLivraisonAgrement: json['dateLivraisonAgrement'] != null ? DateTime.tryParse(json['dateLivraisonAgrement'] as String) : null,
      dateRenouvellementAgrement: json['dateRenouvellementAgrement'] != null ? DateTime.tryParse(json['dateRenouvellementAgrement'] as String) : null,
      assuranceRCProNom: json['assuranceRCProNom'] as String?,
      assuranceRCProPolice: json['assuranceRCProPolice'] as String?,
      assuranceAutoNom: json['assuranceAutoNom'] as String?,
      assuranceAutoPolice: json['assuranceAutoPolice'] as String?,
      lieuTravailType: json['lieuTravailType'] != null
          ? LieuTravailTypeCdd.values.firstWhere((e) => e.name == json['lieuTravailType'], orElse: () => LieuTravailTypeCdd.domicileSalarie)
          : null,
      lieuTravailAdresse: json['lieuTravailAdresse'] as String?,
      nomEnfant: json['nomEnfant'] as String?,
      prenomEnfant: json['prenomEnfant'] as String?,
      dateNaissanceEnfant: json['dateNaissanceEnfant'] != null ? DateTime.tryParse(json['dateNaissanceEnfant'] as String) : null,
      motifCdd: json['motifCdd'] as String?,
      personneRemplaceeNom: json['personneRemplaceeNom'] as String?,
      typeDureeCdd: json['typeDureeCdd'] != null
          ? TypeDureeCdd.values.firstWhere((e) => e.name == json['typeDureeCdd'], orElse: () => TypeDureeCdd.datesFixes)
          : null,
      dateDebutContrat: json['dateDebutContrat'] != null ? DateTime.tryParse(json['dateDebutContrat'] as String) : null,
      dateFinContrat: json['dateFinContrat'] != null ? DateTime.tryParse(json['dateFinContrat'] as String) : null,
      personneAbsenteNom: json['personneAbsenteNom'] as String?,
      dureeMinimaale: json['dureeMinimaale'] as String?,
      dureePeriodeEssai: json['dureePeriodeEssai'] as String?,
      dureePeriodeAdaptationJours: (json['dureePeriodeAdaptationJours'] as num?)?.toInt(),
      dateDebutAdaptation: json['dateDebutAdaptation'] != null ? DateTime.tryParse(json['dateDebutAdaptation'] as String) : null,
      dateFinAdaptation: json['dateFinAdaptation'] != null ? DateTime.tryParse(json['dateFinAdaptation'] as String) : null,
      nombreSemaines: (json['nombreSemaines'] as num?)?.toInt(),
      heuresParSemaine: (json['heuresParSemaine'] as num?)?.toDouble(),
      lignesPlanning: (json['lignesPlanning'] as List<dynamic>?)
              ?.map((e) => LignePlanningCdd.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [LignePlanningCdd()],
      planningParEcrit: (json['planningParEcrit'] as bool?) ?? false,
      delaiPrevenanceSemaines: (json['delaiPrevenanceSemaines'] as num?)?.toInt(),
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
      joursFeriesOrdTravailles: (json['joursFeriesOrdTravailles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      tauxMajorationJoursFeries: (json['tauxMajorationJoursFeries'] as num?)?.toDouble(),
      conditionsParticulieres: json['conditionsParticulieres'] as String?,
      telephoneParent2: json['telephoneParent2'] as String?,
      emailParent2: json['emailParent2'] as String?,
      luEtApprouveParent2: json['luEtApprouveParent2'] as String?,
      signatureParent2: json['signatureParent2'] != null ? base64Decode(json['signatureParent2'] as String) : null,
      notesAdaptation: json['notesAdaptation'] as String?,
      lieuSignature: json['lieuSignature'] as String?,
      dateSignature: json['dateSignature'] != null ? DateTime.tryParse(json['dateSignature'] as String) : null,
      luEtApprouveEmployeur: json['luEtApprouveEmployeur'] as String?,
      luEtApproveSalarie: json['luEtApproveSalarie'] as String?,
      signatureEmployeur: json['signatureEmployeur'] != null ? base64Decode(json['signatureEmployeur'] as String) : null,
      signatureSalarie: json['signatureSalarie'] != null ? base64Decode(json['signatureSalarie'] as String) : null,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  ContratCddModel copyWith({
    String? nomNaissanceEmployeur,
    String? nomUsageEmployeur,
    String? prenomEmployeur,
    String? adresseEmployeur,
    String? villeEmployeur,
    String? codePostalEmployeur,
    String? telephoneEmployeur,
    String? emailEmployeur,
    QualiteCddEmployeur? qualiteEmployeur,
    String? numeroPajemploi,
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
    LieuTravailTypeCdd? lieuTravailType,
    String? lieuTravailAdresse,
    String? nomEnfant,
    String? prenomEnfant,
    DateTime? dateNaissanceEnfant,
    String? motifCdd,
    String? personneRemplaceeNom,
    TypeDureeCdd? typeDureeCdd,
    DateTime? dateDebutContrat,
    DateTime? dateFinContrat,
    String? personneAbsenteNom,
    String? dureeMinimaale,
    String? dureePeriodeEssai,
    int? dureePeriodeAdaptationJours,
    DateTime? dateDebutAdaptation,
    DateTime? dateFinAdaptation,
    int? nombreSemaines,
    double? heuresParSemaine,
    List<LignePlanningCdd>? lignesPlanning,
    bool? planningParEcrit,
    int? delaiPrevenanceSemaines,
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
    String? conditionsParticulieres,
    String? telephoneParent2,
    String? emailParent2,
    String? luEtApprouveParent2,
    String? notesAdaptation,
    String? lieuSignature,
    DateTime? dateSignature,
    String? luEtApprouveEmployeur,
    String? luEtApproveSalarie,
    Object? signatureEmployeur = _absent,
    Object? signatureSalarie = _absent,
    Object? signatureParent2 = _absent,
  }) {
    return ContratCddModel(
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
      motifCdd: motifCdd ?? this.motifCdd,
      personneRemplaceeNom: personneRemplaceeNom ?? this.personneRemplaceeNom,
      typeDureeCdd: typeDureeCdd ?? this.typeDureeCdd,
      dateDebutContrat: dateDebutContrat ?? this.dateDebutContrat,
      dateFinContrat: dateFinContrat ?? this.dateFinContrat,
      personneAbsenteNom: personneAbsenteNom ?? this.personneAbsenteNom,
      dureeMinimaale: dureeMinimaale ?? this.dureeMinimaale,
      dureePeriodeEssai: dureePeriodeEssai ?? this.dureePeriodeEssai,
      dureePeriodeAdaptationJours: dureePeriodeAdaptationJours ?? this.dureePeriodeAdaptationJours,
      dateDebutAdaptation: dateDebutAdaptation ?? this.dateDebutAdaptation,
      dateFinAdaptation: dateFinAdaptation ?? this.dateFinAdaptation,
      nombreSemaines: nombreSemaines ?? this.nombreSemaines,
      heuresParSemaine: heuresParSemaine ?? this.heuresParSemaine,
      lignesPlanning: lignesPlanning ?? this.lignesPlanning,
      planningParEcrit: planningParEcrit ?? this.planningParEcrit,
      delaiPrevenanceSemaines: delaiPrevenanceSemaines ?? this.delaiPrevenanceSemaines,
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
      conditionsParticulieres: conditionsParticulieres ?? this.conditionsParticulieres,
      telephoneParent2: telephoneParent2 ?? this.telephoneParent2,
      emailParent2: emailParent2 ?? this.emailParent2,
      luEtApprouveParent2: luEtApprouveParent2 ?? this.luEtApprouveParent2,
      notesAdaptation: notesAdaptation ?? this.notesAdaptation,
      lieuSignature: lieuSignature ?? this.lieuSignature,
      dateSignature: dateSignature ?? this.dateSignature,
      luEtApprouveEmployeur: luEtApprouveEmployeur ?? this.luEtApprouveEmployeur,
      luEtApproveSalarie: luEtApproveSalarie ?? this.luEtApproveSalarie,
      signatureEmployeur: signatureEmployeur == _absent ? this.signatureEmployeur : signatureEmployeur as Uint8List?,
      signatureSalarie: signatureSalarie == _absent ? this.signatureSalarie : signatureSalarie as Uint8List?,
      signatureParent2: signatureParent2 == _absent ? this.signatureParent2 : signatureParent2 as Uint8List?,
    );
  }
}
