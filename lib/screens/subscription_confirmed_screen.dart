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

  // Remplacer la méthode build existante par celle-ci

  @override
  Widget build(BuildContext context) {
    // Récupérer les informations de la structure
    final String structureType =
        widget.structureInfo['structureType'] ?? 'assistante_maternelle';
    final String structureId = widget.structureInfo['structureId'] ?? '';
    final int memberCount = widget.structureInfo['memberCount'] ?? 1;
    final bool isMam = structureType == 'MAM';

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

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
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        centerTitle: true,
      ),
      // Version iPad ou iPhone selon la taille d'écran
      body: isTablet
          ? _buildTabletContent(
              primaryColor, displayName, price, memberCount, isMam, screenSize)
          : _buildPhoneContent(
              primaryColor, displayName, price, memberCount, isMam),
    );
  }

// Méthode pour la version iPhone (garder exactement comme avant)
  Widget _buildPhoneContent(Color primaryColor, String displayName,
      String price, int memberCount, bool isMam) {
    return SafeArea(
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
                            "Vous pouvez gérer votre abonnement à tout moment depuis l'AppStore pour iOS ou GooglePlay pour Android.",
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
                          'structureType':
                              widget.structureInfo['structureType'] ??
                                  'assistante_maternelle',
                          'structureId':
                              widget.structureInfo['structureId'] ?? '',
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
    );
  }

  Widget _buildTabletDetailsGrid(
      String displayName,
      String price,
      int memberCount,
      bool isMam,
      Color primaryColor,
      double maxWidth,
      double maxHeight) {
    // Créer une liste complète de tous les détails possibles
    List<Map<String, dynamic>> allDetails = [
      {
        'icon': Icons.business_outlined,
        'title': 'Type d\'abonnement',
        'value': displayName,
      },
      {
        'icon': Icons.euro_outlined,
        'title': 'Tarif mensuel',
        'value': price,
      },
      {
        'icon': Icons.people_outline,
        'title': 'Nombre de membres',
        'value': '$memberCount membres',
      },
      {
        'icon': Icons.calendar_today_outlined,
        'title': 'Période d\'essai',
        'value': '7 jours gratuits',
      },
      {
        'icon': Icons.payment_outlined,
        'title': 'Mode de facturation',
        'value': 'Mensuelle',
      },
      {
        'icon': Icons.check_circle_outline,
        'title': 'Statut',
        'value': 'Actif',
      },
    ];

    // Filtrer les détails selon le type de structure
    List<Map<String, dynamic>> details = [];

    // Toujours inclure : Type, Prix
    details.add(allDetails[0]); // Type
    details.add(allDetails[1]); // Prix

    // Ajouter le nombre de membres seulement pour MAM
    if (isMam) {
      details.add(allDetails[2]); // Membres
    }

    // Toujours inclure : Période d'essai, Facturation, Statut
    details.add(allDetails[3]); // Période d'essai
    details.add(allDetails[4]); // Facturation
    details.add(allDetails[5]); // Statut

    // Maintenant organiser en rangées selon le nombre d'éléments
    if (isMam) {
      // Pour MAM : 6 éléments total (3 rangées de 2)
      return Column(
        children: [
          // Première rangée : Type et Prix
          Row(
            children: [
              Expanded(
                child: _buildTabletDetailItem(
                  details[0]['icon'],
                  details[0]['title'],
                  details[0]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: _buildTabletDetailItem(
                  details[1]['icon'],
                  details[1]['title'],
                  details[1]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
            ],
          ),

          SizedBox(height: maxHeight * 0.025),

          // Deuxième rangée : Membres et Période d'essai
          Row(
            children: [
              Expanded(
                child: _buildTabletDetailItem(
                  details[2]['icon'],
                  details[2]['title'],
                  details[2]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: _buildTabletDetailItem(
                  details[3]['icon'],
                  details[3]['title'],
                  details[3]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
            ],
          ),

          SizedBox(height: maxHeight * 0.025),

          // Troisième rangée : Facturation et Statut
          Row(
            children: [
              Expanded(
                child: _buildTabletDetailItem(
                  details[4]['icon'],
                  details[4]['title'],
                  details[4]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: _buildTabletDetailItem(
                  details[5]['icon'],
                  details[5]['title'],
                  details[5]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Pour Assistante Maternelle : 5 éléments total (2 rangées de 2 + 1 rangée de 1)
      return Column(
        children: [
          // Première rangée : Type et Prix
          Row(
            children: [
              Expanded(
                child: _buildTabletDetailItem(
                  details[0]['icon'],
                  details[0]['title'],
                  details[0]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: _buildTabletDetailItem(
                  details[1]['icon'],
                  details[1]['title'],
                  details[1]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
            ],
          ),

          SizedBox(height: maxHeight * 0.025),

          // Deuxième rangée : Période d'essai et Facturation
          Row(
            children: [
              Expanded(
                child: _buildTabletDetailItem(
                  details[2]['icon'], // Période d'essai
                  details[2]['title'],
                  details[2]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: _buildTabletDetailItem(
                  details[3]['icon'], // Facturation
                  details[3]['title'],
                  details[3]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
            ],
          ),

          SizedBox(height: maxHeight * 0.025),

          // Troisième rangée : Statut centré
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(), // Espace vide
              ),
              Expanded(
                flex: 3,
                child: _buildTabletDetailItem(
                  details[4]['icon'], // Statut
                  details[4]['title'],
                  details[4]['value'],
                  primaryColor,
                  maxWidth,
                  maxHeight,
                ),
              ),
              Expanded(
                flex: 2,
                child: SizedBox(), // Espace vide
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildTabletDetailItem(IconData icon, String title, String value,
      Color primaryColor, double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: maxWidth * 0.018,
                color: primaryColor,
              ),
              SizedBox(width: maxWidth * 0.01),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: maxWidth * 0.014,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: maxHeight * 0.008),
          Text(
            value,
            style: TextStyle(
              fontSize: maxWidth * 0.016,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF455A64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletActionButton(
      Color primaryColor, double maxWidth, double maxHeight) {
    return Container(
      width: maxWidth * 0.35, // 35% de la largeur de l'écran
      height: maxHeight * 0.08, // 8% de la hauteur de l'écran
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving
            ? null
            : () {
                final String structureType =
                    widget.structureInfo['structureType'] ??
                        'assistante_maternelle';
                final String structureId =
                    widget.structureInfo['structureId'] ?? '';
                final int memberCount =
                    widget.structureInfo['memberCount'] ?? 1;

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
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? SizedBox(
                width: maxWidth * 0.025,
                height: maxWidth * 0.025,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : Text(
                "CONTINUER",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: maxWidth * 0.02,
                  letterSpacing: 1.1,
                ),
              ),
      ),
    );
  }

  Widget _buildTabletContent(Color primaryColor, String displayName,
      String price, int memberCount, bool isMam, Size screenSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculer des dimensions en pourcentages
        final double sideMargin = maxWidth * 0.04; // 4% de marge sur les côtés
        final double columnGap =
            maxWidth * 0.025; // 2.5% d'espace entre colonnes

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              sideMargin, maxHeight * 0.03, sideMargin, maxHeight * 0.02),
          child: Column(
            children: [
              // Section principale avec disposition en rangée pour iPad
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panneau gauche - Confirmation visuelle
                  Expanded(
                    flex: 5,
                    child: Container(
                      margin: EdgeInsets.only(right: columnGap),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(maxWidth * 0.04),
                        child: Column(
                          children: [
                            // Icône de succès avec animation visuelle
                            Container(
                              width: maxWidth * 0.18,
                              height: maxWidth * 0.18,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Container(
                                margin: EdgeInsets.all(maxWidth * 0.015),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  size: maxWidth * 0.08,
                                  color: primaryColor,
                                ),
                              ),
                            ),

                            SizedBox(height: maxHeight * 0.04),

                            // Titre de félicitations
                            Text(
                              "Félicitations !",
                              style: TextStyle(
                                fontSize: maxWidth * 0.035,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: maxHeight * 0.02),

                            // Message de confirmation
                            Text(
                              "Votre abonnement a été activé avec succès",
                              style: TextStyle(
                                fontSize: maxWidth * 0.02,
                                color: Colors.white.withOpacity(0.95),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: maxHeight * 0.04),

                            // Résumé rapide dans une card élégante
                            Container(
                              padding: EdgeInsets.all(maxWidth * 0.025),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Type:",
                                        style: TextStyle(
                                          fontSize: maxWidth * 0.016,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: maxWidth * 0.016,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: maxHeight * 0.015),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Prix:",
                                        style: TextStyle(
                                          fontSize: maxWidth * 0.016,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      Text(
                                        price,
                                        style: TextStyle(
                                          fontSize: maxWidth * 0.018,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isMam) ...[
                                    SizedBox(height: maxHeight * 0.015),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Membres:",
                                          style: TextStyle(
                                            fontSize: maxWidth * 0.016,
                                            color:
                                                Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                        Text(
                                          "$memberCount membres",
                                          style: TextStyle(
                                            fontSize: maxWidth * 0.016,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Panneau droit - Détails complets
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        // Section des détails de l'abonnement
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                offset: const Offset(0, 4),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(maxWidth * 0.03),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Titre section détails
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(maxWidth * 0.012),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.receipt_long,
                                        color: primaryColor,
                                        size: maxWidth * 0.022,
                                      ),
                                    ),
                                    SizedBox(width: maxWidth * 0.015),
                                    Text(
                                      "Détails de votre abonnement",
                                      style: TextStyle(
                                        fontSize: maxWidth * 0.024,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: maxHeight * 0.03),

                                // Grille de détails pour iPad
                                _buildTabletDetailsGrid(
                                    displayName,
                                    price,
                                    memberCount,
                                    isMam,
                                    primaryColor,
                                    maxWidth,
                                    maxHeight),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: maxHeight * 0.03),

                        // Informations supplémentaires
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.025),
                          decoration: BoxDecoration(
                            color: lightBlue,
                            borderRadius: BorderRadius.circular(18),
                            border:
                                Border.all(color: primaryBlue.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                offset: const Offset(0, 3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(maxWidth * 0.015),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.settings,
                                  color: primaryBlue,
                                  size: maxWidth * 0.022,
                                ),
                              ),
                              SizedBox(width: maxWidth * 0.02),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Gestion de l'abonnement",
                                      style: TextStyle(
                                        fontSize: maxWidth * 0.018,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF455A64),
                                      ),
                                    ),
                                    SizedBox(height: maxHeight * 0.005),
                                    Text(
                                      "Vous pouvez modifier ou résilier votre abonnement à tout moment depuis l'AppStore pour iOS ou GooglePlay pour Android.",
                                      style: TextStyle(
                                        fontSize: maxWidth * 0.016,
                                        height: 1.4,
                                        color: const Color(0xFF455A64),
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
                  ),
                ],
              ),

              SizedBox(height: maxHeight * 0.05),

              // Bouton d'action adaptatif pour iPad
              _buildTabletActionButton(primaryColor, maxWidth, maxHeight),
            ],
          ),
        );
      },
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
