import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionConfirmedScreen extends StatefulWidget {
  final Map<String, dynamic> structureInfo;

  const SubscriptionConfirmedScreen({
    Key? key,
    required this.structureInfo,
  }) : super(key: key);

  @override
  _SubscriptionConfirmedScreenState createState() =>
      _SubscriptionConfirmedScreenState();
}

class _SubscriptionConfirmedScreenState
    extends State<SubscriptionConfirmedScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Sauvegarder les informations d'abonnement dans Firestore dès l'affichage de l'écran
    _saveSubscriptionInfo();
  }

  // Fonction pour sauvegarder les informations d'abonnement
  Future<void> _saveSubscriptionInfo() async {
    try {
      setState(() {
        _isSaving = true;
      });

      final String structureType =
          widget.structureInfo['structureType'] ?? 'assistante_maternelle';
      final String structureId = widget.structureInfo['structureId'] ?? '';
      final int memberCount = widget.structureInfo['memberCount'] ?? 1;

      // Obtenir l'utilisateur courant
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 1. Créer ou mettre à jour l'abonnement dans la collection 'subscriptions'
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': currentUser.uid,
        'structureType': structureType,
        'memberCount': memberCount,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'trialEndsAt':
            Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
      });

      print(
          "✅ Abonnement enregistré dans Firestore: type=$structureType, membres=$memberCount");

      // 2. Mettre à jour le document principal de la structure avec le maxMemberCount
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(currentUser.uid)
          .update({
        'maxMemberCount': memberCount,
        'subscriptionActive': true,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Structure mise à jour avec maxMemberCount=$memberCount");

      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      print("❌ Erreur lors de l'enregistrement de l'abonnement: $e");
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer les informations de la structure
    final String structureType =
        widget.structureInfo['structureType'] ?? 'assistante_maternelle';
    final String structureId = widget.structureInfo['structureId'] ?? '';
    final int memberCount = widget.structureInfo['memberCount'] ?? 1;
    final bool isMam = structureType == 'MAM';

    // Mapping des types techniques vers les noms d'affichage
    Map<String, String> structureDisplayNames = {
      'assistante_maternelle': 'Assistante Maternelle',
      'MAM': 'Maison d\'Assistantes Maternelles',
    };

    // Déterminer le prix selon le type et le nombre de membres
    String price;
    if (isMam) {
      switch (memberCount) {
        case 2:
          price = '22 € / mois';
          break;
        case 3:
          price = '32 € / mois';
          break;
        case 4:
          price = '40 € / mois';
          break;
        default:
          price = '22 € / mois';
      }
    } else {
      price = '12 € / mois';
    }

    // Obtenir le nom d'affichage
    String displayName = structureDisplayNames[structureType] ?? "Structure";

    // Couleur principale en fonction du type de structure
    Color primaryColor = isMam ? primaryRed : primaryBlue;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Abonnement activé",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        centerTitle: true,
      ),
      // Utilisation d'un SafeArea pour éviter les débordements
      body: SafeArea(
        child: Column(
          children: [
            // Contenu principal avec défilement
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // En-tête avec icône de succès
                    Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 70,
                        color: primaryColor,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Titre
                    Text(
                      "Félicitations !",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Message de confirmation
                    Text(
                      "Votre abonnement $displayName a été activé avec succès.",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // Détails de l'abonnement
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: primaryColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Détails de votre abonnement",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF455A64),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            // Type d'abonnement
                            _buildInfoRow(
                              icon: Icons.business,
                              title: "Type",
                              value: displayName,
                              color: primaryColor,
                            ),

                            const SizedBox(height: 10),

                            // Prix
                            _buildInfoRow(
                              icon: Icons.euro,
                              title: "Prix",
                              value: price,
                              color: primaryColor,
                            ),

                            const SizedBox(height: 10),

                            // Nombre de membres (si MAM)
                            if (isMam) ...[
                              _buildInfoRow(
                                icon: Icons.people,
                                title: "Membres",
                                value: "$memberCount membres",
                                color: primaryColor,
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Période d'essai
                            _buildInfoRow(
                              icon: Icons.date_range,
                              title: "Période d'essai",
                              value: "7 jours gratuits",
                              color: primaryColor,
                            ),

                            const SizedBox(height: 10),

                            // Facturation
                            _buildInfoRow(
                              icon: Icons.payment,
                              title: "Facturation",
                              value: "Mensuelle",
                              color: primaryColor,
                            ),

                            const SizedBox(height: 10),

                            // Statut
                            _buildInfoRow(
                              icon: Icons.check_circle_outline,
                              title: "Statut",
                              value: "Actif",
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Information supplémentaire
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Vous pouvez gérer votre abonnement à tout moment depuis les paramètres de votre compte.",
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Bouton fixe en bas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          // Rediriger vers la page des informations de structure
                          context.go('/structure-info', extra: {
                            'structureType': structureType,
                            'structureId': structureId,
                            'memberCount': memberCount,
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text(
                          "CONTINUER",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
