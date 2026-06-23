import 'dart:typed_data';

class _Absent { const _Absent(); }
const _absent = _Absent();

enum TypeContratOriginal { cdi, cdd }

extension TypeContratOriginalLabel on TypeContratOriginal {
  String get label => this == TypeContratOriginal.cdi ? 'CDI' : 'CDD';
}

class AvenantModel {
  // ── Contrat original ──────────────────────────────────────────────────────
  TypeContratOriginal? typeContratOriginal;
  DateTime? dateContratOriginal;
  String? nomEnfant;
  String? prenomEnfant;

  // ── Employeur ─────────────────────────────────────────────────────────────
  String? nomNaissanceEmployeur;
  String? nomUsageEmployeur;
  String? prenomEmployeur;
  String? adresseEmployeur;
  String? villeEmployeur;
  String? codePostalEmployeur;
  String? numeroPajemploi;

  // ── Salarié ───────────────────────────────────────────────────────────────
  String? nomNaissanceSalarie;
  String? nomUsageSalarie;
  String? prenomSalarie;
  String? adresseSalarie;
  String? villeSalarie;
  String? codePostalSalarie;
  String? numeroSecu;

  // ── Modifications ─────────────────────────────────────────────────────────
  String? modificationsTexte;
  DateTime? dateExecution;

  // ── Signatures ────────────────────────────────────────────────────────────
  String? lieuSignature;
  DateTime? dateSignature;
  String? luEtApprouveEmployeur;
  String? luEtApproveSalarie;
  Uint8List? signatureEmployeur;
  Uint8List? signatureSalarie;

  AvenantModel({
    this.typeContratOriginal,
    this.dateContratOriginal,
    this.nomEnfant,
    this.prenomEnfant,
    this.nomNaissanceEmployeur,
    this.nomUsageEmployeur,
    this.prenomEmployeur,
    this.adresseEmployeur,
    this.villeEmployeur,
    this.codePostalEmployeur,
    this.numeroPajemploi,
    this.nomNaissanceSalarie,
    this.nomUsageSalarie,
    this.prenomSalarie,
    this.adresseSalarie,
    this.villeSalarie,
    this.codePostalSalarie,
    this.numeroSecu,
    this.modificationsTexte,
    this.dateExecution,
    this.lieuSignature,
    this.dateSignature,
    this.luEtApprouveEmployeur,
    this.luEtApproveSalarie,
    this.signatureEmployeur,
    this.signatureSalarie,
  });

  bool get isComplete =>
      typeContratOriginal != null &&
      dateContratOriginal != null &&
      (nomNaissanceEmployeur ?? '').isNotEmpty &&
      (prenomEmployeur ?? '').isNotEmpty &&
      (nomNaissanceSalarie ?? '').isNotEmpty &&
      (prenomSalarie ?? '').isNotEmpty &&
      (modificationsTexte ?? '').isNotEmpty &&
      dateExecution != null &&
      (lieuSignature ?? '').isNotEmpty &&
      dateSignature != null &&
      signatureEmployeur != null &&
      signatureSalarie != null;

  Map<String, dynamic> toJson() => {
        'typeContratOriginal': typeContratOriginal?.name,
        'dateContratOriginal': dateContratOriginal?.toIso8601String(),
        'nomEnfant': nomEnfant,
        'prenomEnfant': prenomEnfant,
        'nomNaissanceEmployeur': nomNaissanceEmployeur,
        'nomUsageEmployeur': nomUsageEmployeur,
        'prenomEmployeur': prenomEmployeur,
        'adresseEmployeur': adresseEmployeur,
        'villeEmployeur': villeEmployeur,
        'codePostalEmployeur': codePostalEmployeur,
        'numeroPajemploi': numeroPajemploi,
        'nomNaissanceSalarie': nomNaissanceSalarie,
        'nomUsageSalarie': nomUsageSalarie,
        'prenomSalarie': prenomSalarie,
        'adresseSalarie': adresseSalarie,
        'villeSalarie': villeSalarie,
        'codePostalSalarie': codePostalSalarie,
        'numeroSecu': numeroSecu,
        'modificationsTexte': modificationsTexte,
        'dateExecution': dateExecution?.toIso8601String(),
        'lieuSignature': lieuSignature,
        'dateSignature': dateSignature?.toIso8601String(),
        'luEtApprouveEmployeur': luEtApprouveEmployeur,
        'luEtApproveSalarie': luEtApproveSalarie,
      };

  factory AvenantModel.fromJson(Map<String, dynamic> json) => AvenantModel(
        typeContratOriginal: json['typeContratOriginal'] != null
            ? TypeContratOriginal.values.firstWhere(
                (e) => e.name == json['typeContratOriginal'],
                orElse: () => TypeContratOriginal.cdi)
            : null,
        dateContratOriginal: json['dateContratOriginal'] != null
            ? DateTime.tryParse(json['dateContratOriginal'] as String)
            : null,
        nomEnfant: json['nomEnfant'] as String?,
        prenomEnfant: json['prenomEnfant'] as String?,
        nomNaissanceEmployeur: json['nomNaissanceEmployeur'] as String?,
        nomUsageEmployeur: json['nomUsageEmployeur'] as String?,
        prenomEmployeur: json['prenomEmployeur'] as String?,
        adresseEmployeur: json['adresseEmployeur'] as String?,
        villeEmployeur: json['villeEmployeur'] as String?,
        codePostalEmployeur: json['codePostalEmployeur'] as String?,
        numeroPajemploi: json['numeroPajemploi'] as String?,
        nomNaissanceSalarie: json['nomNaissanceSalarie'] as String?,
        nomUsageSalarie: json['nomUsageSalarie'] as String?,
        prenomSalarie: json['prenomSalarie'] as String?,
        adresseSalarie: json['adresseSalarie'] as String?,
        villeSalarie: json['villeSalarie'] as String?,
        codePostalSalarie: json['codePostalSalarie'] as String?,
        numeroSecu: json['numeroSecu'] as String?,
        modificationsTexte: json['modificationsTexte'] as String?,
        dateExecution: json['dateExecution'] != null
            ? DateTime.tryParse(json['dateExecution'] as String)
            : null,
        lieuSignature: json['lieuSignature'] as String?,
        dateSignature: json['dateSignature'] != null
            ? DateTime.tryParse(json['dateSignature'] as String)
            : null,
        luEtApprouveEmployeur: json['luEtApprouveEmployeur'] as String?,
        luEtApproveSalarie: json['luEtApproveSalarie'] as String?,
      );

  AvenantModel copyWith({
    TypeContratOriginal? typeContratOriginal,
    DateTime? dateContratOriginal,
    String? nomEnfant,
    String? prenomEnfant,
    String? nomNaissanceEmployeur,
    String? nomUsageEmployeur,
    String? prenomEmployeur,
    String? adresseEmployeur,
    String? villeEmployeur,
    String? codePostalEmployeur,
    String? numeroPajemploi,
    String? nomNaissanceSalarie,
    String? nomUsageSalarie,
    String? prenomSalarie,
    String? adresseSalarie,
    String? villeSalarie,
    String? codePostalSalarie,
    String? numeroSecu,
    String? modificationsTexte,
    DateTime? dateExecution,
    String? lieuSignature,
    DateTime? dateSignature,
    String? luEtApprouveEmployeur,
    String? luEtApproveSalarie,
    Object? signatureEmployeur = _absent,
    Object? signatureSalarie = _absent,
  }) =>
      AvenantModel(
        typeContratOriginal: typeContratOriginal ?? this.typeContratOriginal,
        dateContratOriginal: dateContratOriginal ?? this.dateContratOriginal,
        nomEnfant: nomEnfant ?? this.nomEnfant,
        prenomEnfant: prenomEnfant ?? this.prenomEnfant,
        nomNaissanceEmployeur: nomNaissanceEmployeur ?? this.nomNaissanceEmployeur,
        nomUsageEmployeur: nomUsageEmployeur ?? this.nomUsageEmployeur,
        prenomEmployeur: prenomEmployeur ?? this.prenomEmployeur,
        adresseEmployeur: adresseEmployeur ?? this.adresseEmployeur,
        villeEmployeur: villeEmployeur ?? this.villeEmployeur,
        codePostalEmployeur: codePostalEmployeur ?? this.codePostalEmployeur,
        numeroPajemploi: numeroPajemploi ?? this.numeroPajemploi,
        nomNaissanceSalarie: nomNaissanceSalarie ?? this.nomNaissanceSalarie,
        nomUsageSalarie: nomUsageSalarie ?? this.nomUsageSalarie,
        prenomSalarie: prenomSalarie ?? this.prenomSalarie,
        adresseSalarie: adresseSalarie ?? this.adresseSalarie,
        villeSalarie: villeSalarie ?? this.villeSalarie,
        codePostalSalarie: codePostalSalarie ?? this.codePostalSalarie,
        numeroSecu: numeroSecu ?? this.numeroSecu,
        modificationsTexte: modificationsTexte ?? this.modificationsTexte,
        dateExecution: dateExecution ?? this.dateExecution,
        lieuSignature: lieuSignature ?? this.lieuSignature,
        dateSignature: dateSignature ?? this.dateSignature,
        luEtApprouveEmployeur: luEtApprouveEmployeur ?? this.luEtApprouveEmployeur,
        luEtApproveSalarie: luEtApproveSalarie ?? this.luEtApproveSalarie,
        signatureEmployeur: signatureEmployeur == _absent
            ? this.signatureEmployeur
            : signatureEmployeur as Uint8List?,
        signatureSalarie: signatureSalarie == _absent
            ? this.signatureSalarie
            : signatureSalarie as Uint8List?,
      );
}
