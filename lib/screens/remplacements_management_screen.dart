// remplacements_management_screen.dart
//
// Permet à la propriétaire d'une structure d'inviter une remplaçante
// (congé maternité, arrêt maladie, etc.) avec SON PROPRE mot de passe, pour
// une période de dates précise, et de suivre/annuler les remplacements en
// cours. Conventions de saisie email/liste calquées sur add-mam-members.dart.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RemplacementsManagementScreen extends StatefulWidget {
  const RemplacementsManagementScreen({Key? key}) : super(key: key);

  @override
  State<RemplacementsManagementScreen> createState() =>
      _RemplacementsManagementScreenState();
}

class _RemplacementsManagementScreenState
    extends State<RemplacementsManagementScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  DateTimeRange? _selectedRange;
  bool _isSubmitting = false;
  String? _errorMessage;

  String get _structureId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      helpText: "Période du remplacement",
      saveText: "Valider",
      confirmText: "Valider",
    );
    if (range != null) {
      setState(() => _selectedRange = range);
    }
  }

  Future<void> _createRemplacement() async {
    final String email = _emailController.text.trim().toLowerCase();
    final RegExp emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = "Veuillez saisir un email valide.");
      return;
    }
    if (_selectedRange == null) {
      setState(() => _errorMessage = "Veuillez sélectionner une période.");
      return;
    }
    if (_structureId.isEmpty) {
      setState(() => _errorMessage = "Utilisateur non connecté.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('createRemplacement');

      await callable.call({
        'structureId': _structureId,
        'replacementEmail': email,
        'replacementFirstName': _firstNameController.text.trim(),
        'replacementLastName': _lastNameController.text.trim(),
        'startDate': _selectedRange!.start.toIso8601String(),
        'endDate': _selectedRange!.end.toIso8601String(),
      });

      if (!mounted) return;
      _emailController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      setState(() {
        _selectedRange = null;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invitation de remplacement envoyée avec succès"),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            e.message ?? "Erreur lors de la création du remplacement.";
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Une erreur est survenue: $e";
      });
    }
  }

  Future<void> _cancelRemplacement(String remplacementId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Annuler ce remplacement ?"),
        content: const Text(
          "Cela coupera immédiatement l'accès de la remplaçante. Par "
          "sécurité, cela déconnectera aussi vos propres sessions en cours "
          "ailleurs : vous devrez vous reconnecter.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Retour"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Confirmer",
              style: TextStyle(color: primaryRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('cancelRemplacement')
          .call({
        'structureId': _structureId,
        'remplacementId': remplacementId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Remplacement annulé"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(ts.toDate());
    }
    return '-';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'invited':
        return primaryBlue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'En cours';
      case 'invited':
        return 'Invitée';
      case 'cancelled':
        return 'Annulé';
      case 'expired':
        return 'Terminé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Gérer les remplacements",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/structure-management');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Invitez une remplaçante avec SON PROPRE mot de passe "
                      "pour une période donnée. Elle aura un accès identique "
                      "au vôtre (enfants, contrats, documents) uniquement "
                      "pendant cette période, avec un bandeau visible.",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Nouvelle invitation",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: "Prénom de la remplaçante",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: "Nom de la remplaçante",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email de la remplaçante",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Période du remplacement",
                  prefixIcon: const Icon(Icons.date_range),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedRange == null
                      ? "Sélectionner une période"
                      : "${DateFormat('dd/MM/yyyy').format(_selectedRange!.start)}"
                          " → "
                          "${DateFormat('dd/MM/yyyy').format(_selectedRange!.end)}",
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: primaryRed),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createRemplacement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Envoyer l'invitation",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Remplacements",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _structureId.isEmpty
                  ? null
                  : FirebaseFirestore.instance
                      .collection('structures')
                      .doc(_structureId)
                      .collection('remplacements')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text("Erreur de chargement: ${snapshot.error}"),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Aucun remplacement pour le moment.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final String status = (data['status'] ?? '').toString();
                    final String name = [
                      (data['replacementFirstName'] ?? '').toString(),
                      (data['replacementLastName'] ?? '').toString(),
                    ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
                    final String displayName =
                        name.isEmpty ? (data['replacementEmail'] ?? '').toString() : name;
                    final bool canCancel =
                        status == 'invited' || status == 'active';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            title: Text(
                              displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${data['replacementEmail'] ?? ''}\n"
                              "${_formatTimestamp(data['startDate'])} → "
                              "${_formatTimestamp(data['endDate'])}",
                            ),
                            isThreeLine: true,
                            // Seul le badge de statut reste en trailing : un
                            // ListTile impose une hauteur fixe à trailing,
                            // insuffisante pour empiler badge + bouton
                            // (provoquait un RenderFlex overflow).
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (canCancel)
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: 8, bottom: 4),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      _cancelRemplacement(doc.id),
                                  child: const Text(
                                    "Annuler",
                                    style: TextStyle(color: primaryRed),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
