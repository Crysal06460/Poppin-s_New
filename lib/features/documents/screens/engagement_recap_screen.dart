import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';
import 'package:poppins_app/features/documents/services/engagement_storage_service.dart';
import 'package:poppins_app/features/documents/services/pdf_generator_service.dart';
import 'package:poppins_app/features/documents/screens/engagement_pdf_viewer_screen.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);
const Color _fondApp = Color(0xFFF7F9FC);

/// Écran de récapitulatif avant génération du PDF.
///
/// Affiche toutes les données saisies dans le wizard, organisées en sections.
/// Bouton principal "Générer le PDF" déclenche la création et l'upload Firebase.
class EngagementRecapScreen extends StatefulWidget {
  final EngagementReciproqueModel model;
  final String userId;

  const EngagementRecapScreen({
    super.key,
    required this.model,
    required this.userId,
  });

  @override
  State<EngagementRecapScreen> createState() => _EngagementRecapScreenState();
}

class _EngagementRecapScreenState extends State<EngagementRecapScreen> {
  bool _isGenerating = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');

  /// Formate une date ou retourne "Non renseigné".
  String _formatDate(DateTime? date) {
    if (date == null) return 'Non renseigné';
    return _dateFormat.format(date);
  }

  /// Génère le PDF, l'uploade sur Firebase Storage, supprime le brouillon
  /// puis navigue vers [EngagementPdfViewerScreen].
  Future<void> _genererPdf() async {
    setState(() => _isGenerating = true);
    try {
      final pdfService = PdfGeneratorService();
      final Uint8List pdfBytes =
          await pdfService.genererEngagementPdf(widget.model);
      final String nomFichier = pdfService.genererNomFichier(widget.model);

      final storageService = EngagementStorageService();
      await storageService.sauvegarderPdfGenere(
          widget.userId, pdfBytes, nomFichier);
      await storageService.supprimerBrouillon(widget.userId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EngagementPdfViewerScreen(
            pdfBytes: pdfBytes,
            nomEnfant: widget.model.nomEnfant ?? 'Engagement',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération : $e'),
          backgroundColor: _primaryRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondApp,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _primaryBlue),
        title: const Text(
          'Récapitulatif',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau d'information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vérifiez toutes les informations avant de générer le PDF.',
                      style: TextStyle(
                        color: _primaryBlue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Section Employeur ─────────────────────────────────────
            _SectionRecap(
              titre: 'Employeur',
              onModifier: () => Navigator.pop(context, 1),
              lignes: [
                _ligneEmployeur(),
                if (widget.model.qualiteEmployeur != null)
                  'Qualité : ${widget.model.qualiteEmployeur!.label}',
                if (widget.model.adresseEmployeur != null)
                  widget.model.adresseEmployeur!,
                _ligneVilleCP(
                  widget.model.villeEmployeur,
                  widget.model.codePostalEmployeur,
                ),
                if (widget.model.telephoneEmployeur?.isNotEmpty == true)
                  'Tél : ${widget.model.telephoneEmployeur}',
                if (widget.model.emailEmployeur?.isNotEmpty == true)
                  'Email : ${widget.model.emailEmployeur}',
              ].whereType<String>().toList(),
            ),
            const SizedBox(height: 12),

            // ─── Section Salarié ───────────────────────────────────────
            _SectionRecap(
              titre: 'Salarié(e)',
              onModifier: () => Navigator.pop(context, 2),
              lignes: [
                _ligneSalarie(),
                if (widget.model.adresseSalarie != null)
                  widget.model.adresseSalarie!,
                _ligneVilleCP(
                  widget.model.villeSalarie,
                  widget.model.codePostalSalarie,
                ),
                if (widget.model.telephoneSalarie?.isNotEmpty == true)
                  'Tél : ${widget.model.telephoneSalarie}',
                if (widget.model.emailSalarie?.isNotEmpty == true)
                  'Email : ${widget.model.emailSalarie}',
              ].whereType<String>().toList(),
            ),
            const SizedBox(height: 12),

            // ─── Section Enfant & Dates ────────────────────────────────
            _SectionRecap(
              titre: 'Enfant & Contrat',
              onModifier: () => Navigator.pop(context, 3),
              lignes: [
                if (widget.model.nomEnfant?.isNotEmpty == true)
                  'Enfant : ${widget.model.nomEnfant}',
                'Début contrat : ${_formatDate(widget.model.dateDebutContrat)}',
              ],
            ),
            const SizedBox(height: 12),

            // ─── Section Conditions ────────────────────────────────────
            _SectionRecap(
              titre: "Conditions d'accueil",
              onModifier: () => Navigator.pop(context, 4),
              lignes: [
                if (widget.model.heuresParSemaine != null)
                  '${widget.model.heuresParSemaine!.toStringAsFixed(1)} h / semaine',
                if (widget.model.heuresParMois != null)
                  '${widget.model.heuresParMois!.toStringAsFixed(1)} h / mois',
                if (widget.model.semainesParAn != null)
                  '${widget.model.semainesParAn} semaines / an',
              ],
            ),
            const SizedBox(height: 12),

            // ─── Section Rémunération ──────────────────────────────────
            _SectionRecap(
              titre: 'Rémunération',
              onModifier: () => Navigator.pop(context, 5),
              lignes: [
                if (widget.model.salaireMensuelBrut != null)
                  'Salaire mensuel brut : ${widget.model.salaireMensuelBrut!.toStringAsFixed(2).replaceAll('.', ',')} €',
                if (widget.model.salaireHoraireBrut != null)
                  'Salaire horaire brut : ${widget.model.salaireHoraireBrut!.toStringAsFixed(2).replaceAll('.', ',')} €',
              ],
            ),
            const SizedBox(height: 12),

            // ─── Section Lieu & Date de signature ─────────────────────
            _SectionRecap(
              titre: 'Lieu & Date de signature',
              onModifier: () => Navigator.pop(context, 6),
              lignes: [
                if (widget.model.lieuSignature?.isNotEmpty == true)
                  'Lieu : ${widget.model.lieuSignature}',
                'Date : ${_formatDate(widget.model.dateSignature)}',
              ],
            ),
            const SizedBox(height: 12),

            // ─── Section Signatures ────────────────────────────────────
            _buildSectionSignatures(),
            const SizedBox(height: 32),
          ],
        ),
      ),

      // ─── Bouton flottant "Générer le PDF" ──────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFECF0F1))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _genererPdf,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            label: Text(
              _isGenerating ? 'Génération en cours…' : 'Générer le PDF',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primaryBlue.withAlpha(153),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers de construction de lignes ────────────────────────────────

  /// Ligne "Civilité Prénom NOM" pour l'employeur.
  String _ligneEmployeur() {
    final civilite = widget.model.civiliteEmployeur?.label ?? '';
    final prenom = widget.model.prenomEmployeur ?? '';
    final nom = widget.model.nomEmployeur ?? '';
    return '$civilite $prenom $nom'.trim();
  }

  /// Ligne "Civilité Prénom NOM" pour le salarié.
  String _ligneSalarie() {
    final civilite = widget.model.civiliteSalarie?.label ?? '';
    final prenom = widget.model.prenomSalarie ?? '';
    final nom = widget.model.nomSalarie ?? '';
    return '$civilite $prenom $nom'.trim();
  }

  /// Ligne "Ville (CP)" ou chaîne vide si les deux sont null.
  String? _ligneVilleCP(String? ville, String? cp) {
    if (ville == null && cp == null) return null;
    return '${ville ?? ''} (${cp ?? ''})'.trim();
  }

  /// Section signatures avec miniatures ou indicateur "Non signé".
  Widget _buildSectionSignatures() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0F3F5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Signatures',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 7),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: _primaryBlue),
                  label: const Text(
                    'Modifier',
                    style: TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Signature employeur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Employeur',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF636E72),
                        ),
                      ),
                      const SizedBox(height: 8),
                      widget.model.signatureEmployeur != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                widget.model.signatureEmployeur!,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Text(
                              'Non signé',
                              style: TextStyle(
                                color: Color(0xFFBDC3C7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Signature salarié
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Salarié(e)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF636E72),
                        ),
                      ),
                      const SizedBox(height: 8),
                      widget.model.signatureSalarie != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                widget.model.signatureSalarie!,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Text(
                              'Non signé',
                              style: TextStyle(
                                color: Color(0xFFBDC3C7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget interne : carte de section récapitulatif
// ─────────────────────────────────────────────────────────────────────────────

/// Carte blanche avec titre, bouton "Modifier" et liste de lignes d'info.
class _SectionRecap extends StatelessWidget {
  final String titre;
  final VoidCallback onModifier;
  final List<String> lignes;

  const _SectionRecap({
    required this.titre,
    required this.onModifier,
    required this.lignes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0F3F5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
                TextButton.icon(
                  onPressed: onModifier,
                  icon: const Icon(Icons.edit_outlined, size: 16, color: _primaryBlue),
                  label: const Text(
                    'Modifier',
                    style: TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lignes d'information
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lignes
                  .map(
                    (ligne) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        ligne,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF636E72),
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
