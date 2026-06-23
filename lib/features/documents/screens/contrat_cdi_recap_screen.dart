import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/contrat_cdi_model.dart';
import 'package:poppins_app/features/documents/services/contrat_cdi_pdf_service.dart';
import 'package:poppins_app/features/documents/services/contrat_cdi_storage_service.dart';
import 'package:poppins_app/features/documents/screens/contrat_cdi_pdf_viewer_screen.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class ContratCdiRecapScreen extends StatefulWidget {
  final ContratCdiModel model;
  final String userId;

  const ContratCdiRecapScreen({super.key, required this.model, required this.userId});

  @override
  State<ContratCdiRecapScreen> createState() => _ContratCdiRecapScreenState();
}

class _ContratCdiRecapScreenState extends State<ContratCdiRecapScreen> {
  bool _isGenerating = false;
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _pdfService = ContratCdiPdfService();
  final _storage = ContratCdiStorageService();

  String _d(DateTime? d) => d != null ? _dateFmt.format(d) : '—';
  String _v(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();
  String _e(double? v) => v != null ? '${v.toStringAsFixed(2).replaceAll('.', ',')} €' : '—';

  Future<void> _generer() async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await _pdfService.genererPdf(widget.model);

      final prenom = (widget.model.prenomEnfant ?? 'Enfant').replaceAll(' ', '_');
      final nom = (widget.model.nomEnfant ?? '').replaceAll(' ', '_');
      final date = DateFormat('yyyyMMdd').format(widget.model.dateSignature ?? DateTime.now());
      final nomFichier = 'CDI_${prenom}_$nom\_$date.pdf';

      await _storage.sauvegarderPdfGenere(widget.userId, pdfBytes, nomFichier);
      await _storage.supprimerBrouillon(widget.userId);

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ContratCdiPdfViewerScreen(
            model: widget.model,
            nomEnfant: '${widget.model.prenomEnfant ?? ''} ${widget.model.nomEnfant ?? ''}'.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: _primaryRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _primaryBlue),
        title: const Text('Récapitulatif CDI', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            const SizedBox(height: 16),

            _buildSection('Employeur', 1, [
              _row('Nom', '${_v(m.nomNaissanceEmployeur)} — ${_v(m.prenomEmployeur)}'),
              _row('Adresse', '${_v(m.adresseEmployeur)}, ${_v(m.villeEmployeur)} ${_v(m.codePostalEmployeur)}'),
              _row('Qualité', m.qualiteEmployeur?.label ?? '—'),
              _row('N° Pajemploi', _v(m.numeroPajemploi)),
            ]),

            _buildSection('Assistante maternelle', 2, [
              _row('Nom', '${_v(m.nomNaissanceSalarie)} — ${_v(m.prenomSalarie)}'),
              _row('Adresse', '${_v(m.adresseSalarie)}, ${_v(m.villeSalarie)} ${_v(m.codePostalSalarie)}'),
              _row('Agrément', _v(m.referenceAgrement)),
              _row('Date agrément', _d(m.dateLivraisonAgrement)),
            ]),

            _buildSection('Enfant, lieu & date', 3, [
              _row('Enfant', '${_v(m.prenomEnfant)} ${_v(m.nomEnfant)} — né(e) le ${_d(m.dateNaissanceEnfant)}'),
              _row('Lieu de travail', m.lieuTravailType == LieuTravailType.domicileSalarie ? 'Domicile salarié' : 'MAM'),
              _row('Adresse lieu', _v(m.lieuTravailAdresse)),
              _row('Date d\'embauche', _d(m.dateEmbauche)),
            ]),

            _buildSection('Horaires d\'accueil', 4, [
              _row('Type', m.typeAccueil == TypeAccueilCdi.cas1_52semaines ? 'Cas 1 — 52 semaines' : 'Cas 2 — ${m.nombreSemainesGarde ?? "??"} semaines'),
              _row('Heures/semaine', m.heuresParSemaine != null ? '${m.heuresParSemaine}h' : '—'),
              _row('Planning', m.planningParEcrit ? 'Par écrit' : '${m.lignesPlanning.where((l) => l.jourTravail.isNotEmpty).length} jour(s) renseigné(s)'),
            ]),

            _buildSection('Rémunération', 5, [
              _row('Salaire horaire brut', _e(m.salaireHoraireBrut)),
              _row('Salaire horaire net', _e(m.salaireHoraireNet)),
              _row('Salaire mensuel brut', _e(m.salaireMensuelBrut)),
              _row('Salaire mensuel net', _e(m.salaireMensuelNet)),
              if (m.jourPaiementSalaire != null) _row('Paiement le', '${m.jourPaiementSalaire} du mois'),
            ]),

            _buildSection('Repos & Jours fériés', 6, [
              _row('Repos hebdomadaire', _v(m.jourReposHebdomadaire)),
              _row('Compensation repos', m.travailReposMajore ? 'Rémunéré +25%' : 'Récupéré +25%'),
              _row('1er mai', m.premierMaiChome ? 'Chômé' : 'Travaillé'),
              _row('Jours fériés travaillés', m.joursFeriesOrdTravailles.isEmpty ? 'Aucun' : '${m.joursFeriesOrdTravailles.length} jour(s)'),
            ]),

            _buildSection('Signatures', 7, [
              _row('Lieu', _v(m.lieuSignature)),
              _row('Date', _d(m.dateSignature)),
              _row('Signature employeur', m.signatureEmployeur != null ? '✓ Apposée' : '⚠ Manquante'),
              _row('Signature salarié', m.signatureSalarie != null ? '✓ Apposée' : '⚠ Manquante'),
            ]),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFECF0F1))),
        ),
        child: ElevatedButton.icon(
          onPressed: _isGenerating ? null : _generer,
          icon: _isGenerating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          label: Text(
            _isGenerating ? 'Génération en cours…' : 'Générer le contrat PDF',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primaryBlue, Color(0xFF2980B9)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vérifiez les informations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 2),
                Text('Appuyez sur une section pour modifier.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String titre, int etape, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            onTap: () => Navigator.pop(context, etape),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: _lightBlue, shape: BoxShape.circle),
                    child: Center(child: Text('$etape', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryBlue))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D3436)))),
                  const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF95A5A6)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFECF0F1)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final isWarning = value.startsWith('⚠');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF636E72)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isWarning ? _primaryRed : const Color(0xFF2D3436)))),
        ],
      ),
    );
  }
}
