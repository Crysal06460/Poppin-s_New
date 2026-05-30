import 'dart:convert';
import 'dart:typed_data';

// Sentinel pour distinguer "non fourni" de "explicitement null" dans copyWith.
class _Absent {
  const _Absent();
}

const _absent = _Absent();

enum Civilite { mme, monsieur }

enum QualiteEmployeur { pere, mere, tuteur, autre }

extension CiviliteLabel on Civilite {
  String get label => this == Civilite.mme ? 'Mme' : 'M.';
}

extension QualiteLabel on QualiteEmployeur {
  String get label {
    switch (this) {
      case QualiteEmployeur.pere:
        return 'Père';
      case QualiteEmployeur.mere:
        return 'Mère';
      case QualiteEmployeur.tuteur:
        return 'Tuteur';
      case QualiteEmployeur.autre:
        return 'Autre';
    }
  }
}

class EngagementReciproqueModel {
  // Employeur
  Civilite? civiliteEmployeur;
  String? nomEmployeur;
  String? prenomEmployeur;
  String? adresseEmployeur;
  String? villeEmployeur;
  String? codePostalEmployeur;
  QualiteEmployeur? qualiteEmployeur;
  String? telephoneEmployeur;
  String? emailEmployeur;

  // Salarié
  Civilite? civiliteSalarie;
  String? nomSalarie;
  String? prenomSalarie;
  String? adresseSalarie;
  String? villeSalarie;
  String? codePostalSalarie;
  String? telephoneSalarie;
  String? emailSalarie;

  // Enfant & contrat
  String? nomEnfant;
  DateTime? dateDebutContrat;

  // Conditions d'accueil
  double? heuresParSemaine;
  double? heuresParMois;
  int? semainesParAn;

  // Rémunération
  double? salaireMensuelBrut;
  double? salaireHoraireBrut;

  // Lieu & date de signature
  String? lieuSignature;
  DateTime? dateSignature;

  // Signatures (PNG — stockées en base64 dans Firestore)
  Uint8List? signatureEmployeur;
  Uint8List? signatureSalarie;

  EngagementReciproqueModel({
    this.civiliteEmployeur,
    this.nomEmployeur,
    this.prenomEmployeur,
    this.adresseEmployeur,
    this.villeEmployeur,
    this.codePostalEmployeur,
    this.qualiteEmployeur,
    this.telephoneEmployeur,
    this.emailEmployeur,
    this.civiliteSalarie,
    this.nomSalarie,
    this.prenomSalarie,
    this.adresseSalarie,
    this.villeSalarie,
    this.codePostalSalarie,
    this.telephoneSalarie,
    this.emailSalarie,
    this.nomEnfant,
    this.dateDebutContrat,
    this.heuresParSemaine,
    this.heuresParMois,
    this.semainesParAn,
    this.salaireMensuelBrut,
    this.salaireHoraireBrut,
    this.lieuSignature,
    this.dateSignature,
    this.signatureEmployeur,
    this.signatureSalarie,
  });

  bool isComplete() {
    return civiliteEmployeur != null &&
        nomEmployeur != null &&
        nomEmployeur!.trim().length >= 2 &&
        prenomEmployeur != null &&
        prenomEmployeur!.trim().length >= 2 &&
        adresseEmployeur != null &&
        adresseEmployeur!.trim().isNotEmpty &&
        villeEmployeur != null &&
        villeEmployeur!.trim().isNotEmpty &&
        codePostalEmployeur != null &&
        codePostalEmployeur!.trim().length == 5 &&
        qualiteEmployeur != null &&
        civiliteSalarie != null &&
        nomSalarie != null &&
        nomSalarie!.trim().length >= 2 &&
        prenomSalarie != null &&
        prenomSalarie!.trim().length >= 2 &&
        adresseSalarie != null &&
        adresseSalarie!.trim().isNotEmpty &&
        villeSalarie != null &&
        villeSalarie!.trim().isNotEmpty &&
        codePostalSalarie != null &&
        codePostalSalarie!.trim().length == 5 &&
        telephoneSalarie != null &&
        telephoneSalarie!.trim().isNotEmpty &&
        nomEnfant != null &&
        nomEnfant!.trim().isNotEmpty &&
        dateDebutContrat != null &&
        heuresParSemaine != null &&
        heuresParMois != null &&
        semainesParAn != null &&
        salaireMensuelBrut != null &&
        salaireHoraireBrut != null &&
        lieuSignature != null &&
        lieuSignature!.trim().isNotEmpty &&
        dateSignature != null &&
        signatureEmployeur != null &&
        signatureSalarie != null;
  }

  Map<String, dynamic> toJson() {
    return {
      'civiliteEmployeur': civiliteEmployeur?.name,
      'nomEmployeur': nomEmployeur,
      'prenomEmployeur': prenomEmployeur,
      'adresseEmployeur': adresseEmployeur,
      'villeEmployeur': villeEmployeur,
      'codePostalEmployeur': codePostalEmployeur,
      'qualiteEmployeur': qualiteEmployeur?.name,
      'telephoneEmployeur': telephoneEmployeur,
      'emailEmployeur': emailEmployeur,
      'civiliteSalarie': civiliteSalarie?.name,
      'nomSalarie': nomSalarie,
      'prenomSalarie': prenomSalarie,
      'adresseSalarie': adresseSalarie,
      'villeSalarie': villeSalarie,
      'codePostalSalarie': codePostalSalarie,
      'telephoneSalarie': telephoneSalarie,
      'emailSalarie': emailSalarie,
      'nomEnfant': nomEnfant,
      'dateDebutContrat': dateDebutContrat?.toIso8601String(),
      'heuresParSemaine': heuresParSemaine,
      'heuresParMois': heuresParMois,
      'semainesParAn': semainesParAn,
      'salaireMensuelBrut': salaireMensuelBrut,
      'salaireHoraireBrut': salaireHoraireBrut,
      'lieuSignature': lieuSignature,
      'dateSignature': dateSignature?.toIso8601String(),
      'signatureEmployeur': signatureEmployeur != null
          ? base64Encode(signatureEmployeur!)
          : null,
      'signatureSalarie': signatureSalarie != null
          ? base64Encode(signatureSalarie!)
          : null,
    };
  }

  factory EngagementReciproqueModel.fromJson(Map<String, dynamic> json) {
    return EngagementReciproqueModel(
      civiliteEmployeur: json['civiliteEmployeur'] != null
          ? Civilite.values.firstWhere(
              (e) => e.name == json['civiliteEmployeur'],
              orElse: () => Civilite.mme,
            )
          : null,
      nomEmployeur: json['nomEmployeur'] as String?,
      prenomEmployeur: json['prenomEmployeur'] as String?,
      adresseEmployeur: json['adresseEmployeur'] as String?,
      villeEmployeur: json['villeEmployeur'] as String?,
      codePostalEmployeur: json['codePostalEmployeur'] as String?,
      qualiteEmployeur: json['qualiteEmployeur'] != null
          ? QualiteEmployeur.values.firstWhere(
              (e) => e.name == json['qualiteEmployeur'],
              orElse: () => QualiteEmployeur.autre,
            )
          : null,
      telephoneEmployeur: json['telephoneEmployeur'] as String?,
      emailEmployeur: json['emailEmployeur'] as String?,
      civiliteSalarie: json['civiliteSalarie'] != null
          ? Civilite.values.firstWhere(
              (e) => e.name == json['civiliteSalarie'],
              orElse: () => Civilite.mme,
            )
          : null,
      nomSalarie: json['nomSalarie'] as String?,
      prenomSalarie: json['prenomSalarie'] as String?,
      adresseSalarie: json['adresseSalarie'] as String?,
      villeSalarie: json['villeSalarie'] as String?,
      codePostalSalarie: json['codePostalSalarie'] as String?,
      telephoneSalarie: json['telephoneSalarie'] as String?,
      emailSalarie: json['emailSalarie'] as String?,
      nomEnfant: json['nomEnfant'] as String?,
      dateDebutContrat: json['dateDebutContrat'] != null
          ? DateTime.tryParse(json['dateDebutContrat'] as String)
          : null,
      heuresParSemaine: (json['heuresParSemaine'] as num?)?.toDouble(),
      heuresParMois: (json['heuresParMois'] as num?)?.toDouble(),
      semainesParAn: (json['semainesParAn'] as num?)?.toInt(),
      salaireMensuelBrut: (json['salaireMensuelBrut'] as num?)?.toDouble(),
      salaireHoraireBrut: (json['salaireHoraireBrut'] as num?)?.toDouble(),
      lieuSignature: json['lieuSignature'] as String?,
      dateSignature: json['dateSignature'] != null
          ? DateTime.tryParse(json['dateSignature'] as String)
          : null,
      signatureEmployeur: json['signatureEmployeur'] != null
          ? base64Decode(json['signatureEmployeur'] as String)
          : null,
      signatureSalarie: json['signatureSalarie'] != null
          ? base64Decode(json['signatureSalarie'] as String)
          : null,
    );
  }

  EngagementReciproqueModel copyWith({
    Civilite? civiliteEmployeur,
    String? nomEmployeur,
    String? prenomEmployeur,
    String? adresseEmployeur,
    String? villeEmployeur,
    String? codePostalEmployeur,
    QualiteEmployeur? qualiteEmployeur,
    String? telephoneEmployeur,
    String? emailEmployeur,
    Civilite? civiliteSalarie,
    String? nomSalarie,
    String? prenomSalarie,
    String? adresseSalarie,
    String? villeSalarie,
    String? codePostalSalarie,
    String? telephoneSalarie,
    String? emailSalarie,
    String? nomEnfant,
    DateTime? dateDebutContrat,
    double? heuresParSemaine,
    double? heuresParMois,
    int? semainesParAn,
    double? salaireMensuelBrut,
    double? salaireHoraireBrut,
    String? lieuSignature,
    DateTime? dateSignature,
    // Sentinel : passer null efface vraiment la valeur
    Object? signatureEmployeur = _absent,
    Object? signatureSalarie = _absent,
  }) {
    return EngagementReciproqueModel(
      civiliteEmployeur: civiliteEmployeur ?? this.civiliteEmployeur,
      nomEmployeur: nomEmployeur ?? this.nomEmployeur,
      prenomEmployeur: prenomEmployeur ?? this.prenomEmployeur,
      adresseEmployeur: adresseEmployeur ?? this.adresseEmployeur,
      villeEmployeur: villeEmployeur ?? this.villeEmployeur,
      codePostalEmployeur: codePostalEmployeur ?? this.codePostalEmployeur,
      qualiteEmployeur: qualiteEmployeur ?? this.qualiteEmployeur,
      telephoneEmployeur: telephoneEmployeur ?? this.telephoneEmployeur,
      emailEmployeur: emailEmployeur ?? this.emailEmployeur,
      civiliteSalarie: civiliteSalarie ?? this.civiliteSalarie,
      nomSalarie: nomSalarie ?? this.nomSalarie,
      prenomSalarie: prenomSalarie ?? this.prenomSalarie,
      adresseSalarie: adresseSalarie ?? this.adresseSalarie,
      villeSalarie: villeSalarie ?? this.villeSalarie,
      codePostalSalarie: codePostalSalarie ?? this.codePostalSalarie,
      telephoneSalarie: telephoneSalarie ?? this.telephoneSalarie,
      emailSalarie: emailSalarie ?? this.emailSalarie,
      nomEnfant: nomEnfant ?? this.nomEnfant,
      dateDebutContrat: dateDebutContrat ?? this.dateDebutContrat,
      heuresParSemaine: heuresParSemaine ?? this.heuresParSemaine,
      heuresParMois: heuresParMois ?? this.heuresParMois,
      semainesParAn: semainesParAn ?? this.semainesParAn,
      salaireMensuelBrut: salaireMensuelBrut ?? this.salaireMensuelBrut,
      salaireHoraireBrut: salaireHoraireBrut ?? this.salaireHoraireBrut,
      lieuSignature: lieuSignature ?? this.lieuSignature,
      dateSignature: dateSignature ?? this.dateSignature,
      signatureEmployeur: signatureEmployeur == _absent
          ? this.signatureEmployeur
          : signatureEmployeur as Uint8List?,
      signatureSalarie: signatureSalarie == _absent
          ? this.signatureSalarie
          : signatureSalarie as Uint8List?,
    );
  }
}
