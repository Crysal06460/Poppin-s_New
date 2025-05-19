import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionUpgradeScreen extends StatefulWidget {
  const SubscriptionUpgradeScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionUpgradeScreenState createState() =>
      _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState extends State<SubscriptionUpgradeScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // Variables pour stocker les informations actuelles et nouvelles
  bool _isLoading = true;
  bool _isPurchasing = false;
  String _errorMessage = '';
  int _currentMemberCount = 0;
  int _maxMemberCount = 0;
  int _selectedMemberCount = 0;
  String _structureType = '';
  String _structureName = '';
  String _currentPrice = '';
  String _newPrice = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscriptionData();
  }

  Future<void> _loadCurrentSubscriptionData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Récupérer l'utilisateur courant
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      // Récupérer l'ID de la structure
      final String structureId = await _getStructureId();
      if (structureId.isEmpty) throw Exception("ID de structure non trouvé");

      // Récupérer les informations de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (!structureDoc.exists) throw Exception("Structure non trouvée");

      final data = structureDoc.data() ?? {};

      // Récupérer le type de structure
      _structureType = data['structureType'] ?? 'AssistanteMaternelle';
      _structureName = data['structureName'] ?? 'Ma structure';

      // Vérifier si c'est une MAM
      bool isMam = _structureType == 'MAM';
      if (!isMam) {
        throw Exception(
            "Cette fonctionnalité est uniquement disponible pour les MAM");
      }

      // Récupérer le nombre maximum de membres
      if (data.containsKey('maxMemberCount')) {
        _maxMemberCount = data['maxMemberCount'] ?? 3;
      } else if (data.containsKey('subscription') &&
          data['subscription'] != null) {
        _maxMemberCount = data['subscription']['maxMembers'] ?? 3;
      } else {
        _maxMemberCount = 3; // Valeur par défaut pour une MAM
      }

      // Compter le nombre actuel de membres
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .get();

      _currentMemberCount = membersSnapshot.docs.length;

      // Déterminer le prix actuel
      _currentPrice = _getPriceForMembers(_maxMemberCount);

      // Proposer par défaut le niveau d'abonnement suivant
      _selectedMemberCount = _maxMemberCount < 4 ? _maxMemberCount + 1 : 4;
      _newPrice = _getPriceForMembers(_selectedMemberCount);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      // Afficher un message et rediriger vers le dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );

      Future.delayed(Duration(seconds: 2), () {
        context.go('/dashboard');
      });
    }
  }

  // Obtenir le prix pour un nombre donné de membres
  String _getPriceForMembers(int memberCount) {
    switch (memberCount) {
      case 2:
        return '22 € / mois';
      case 3:
        return '32 € / mois';
      case 4:
        return '40 € / mois';
      default:
        return '22 € / mois';
    }
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si c'est un membre MAM, obtenir l'ID de la structure associée
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur
    return user.uid;
  }

  // Fonction pour effectuer la mise à niveau de l'abonnement
  Future<void> _upgradeSubscription() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = '';
    });

    try {
      // Simuler le processus d'achat via in_app_purchase
      // En production, cela devrait appeler le SDK Google Play ou App Store
      await Future.delayed(Duration(seconds: 2)); // Simulation du traitement

      // Dans une vraie implémentation, on utiliserait par exemple:
      // final bool available = await InAppPurchase.instance.isAvailable();
      // if (!available) {
      //   throw Exception("Les achats in-app ne sont pas disponibles");
      // }
      //
      // String productId = 'mam_members_${_selectedMemberCount}';
      // final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({productId});
      // await InAppPurchase.instance.buyNonConsumable(productDetails: response.productDetails.first);

      // Mettre à jour Firestore avec le nouveau nombre de membres
      final String structureId = await _getStructureId();

      // 1. Mettre à jour l'abonnement dans la collection subscriptions
      // Trouver d'abord l'abonnement actif
      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: structureId)
          .where('status', isEqualTo: 'active')
          .get();

      // Mettre à jour ou créer un nouvel abonnement
      if (subscriptionQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(subscriptionQuery.docs.first.id)
            .update({
          'memberCount': _selectedMemberCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('subscriptions').add({
          'structureId': structureId,
          'structureType': 'MAM',
          'memberCount': _selectedMemberCount,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Mettre à jour le document principal de la structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({
        'maxMemberCount': _selectedMemberCount,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Rediriger vers l'écran de confirmation
      context.go('/upgrade-confirmed', extra: {
        'structureType': 'MAM',
        'structureId': structureId,
        'memberCount': _selectedMemberCount,
        'oldMemberCount': _maxMemberCount,
      });
    } catch (e) {
      setState(() {
        _isPurchasing = false;
        _errorMessage = "Erreur lors de la mise à niveau: ${e.toString()}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Widget pour les boutons de sélection du nombre de membres
  Widget _buildMemberCountButton({
    required int count,
    required bool isSelected,
    required Color color,
  }) {
    // Désactiver les options inférieures au nombre actuel de membres
    bool isDisabled = count <= _maxMemberCount;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedMemberCount = count;
                _newPrice = _getPriceForMembers(count);
              });
            },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.shade200
              : (isSelected ? color : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.shade300
                : (isSelected ? color : Colors.grey.shade300),
            width: 1.5,
          ),
          boxShadow: isSelected && !isDisabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDisabled
                    ? Colors.grey
                    : (isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "membres",
              style: TextStyle(
                fontSize: 12,
                color: isDisabled
                    ? Colors.grey
                    : (isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ),
            if (count == _maxMemberCount) ...[
              SizedBox(height: 4),
              Text(
                "actuel",
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color:
                      isSelected ? Colors.white.withOpacity(0.8) : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Mise à niveau abonnement",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryRed),
            )
          : Column(
              children: [
                // En-tête avec couleur selon le type de structure
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      // Structure actuelle
                      Text(
                        _structureName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),

                      // Informations sur l'abonnement actuel
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Abonnement actuel",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "$_maxMemberCount membres",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "•",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  _currentPrice,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre section mise à niveau
                        Text(
                          "Choisir votre nouveau forfait",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                          ),
                        ),
                        SizedBox(height: 20),

                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightBlue,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: primaryRed.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Nombre d'assistantes maternelles dans votre MAM",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF455A64),
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (int i = 2; i <= 4; i++)
                                    _buildMemberCountButton(
                                      count: i,
                                      isSelected: _selectedMemberCount == i,
                                      color: primaryRed,
                                    ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                "Le prix de l'abonnement s'adapte au nombre de membres.",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  color: Color(0xFF455A64),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 30),

                        // Récapitulatif de la mise à niveau
                        if (_selectedMemberCount > _maxMemberCount) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: primaryRed),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "Récapitulatif de la mise à niveau",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryRed,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 20),

                                // De - À
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            "De",
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "$_maxMemberCount membres",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _currentPrice,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: primaryRed,
                                      size: 24,
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                            "À",
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "$_selectedMemberCount membres",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryRed,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _newPrice,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: primaryRed,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 20),

                                // Note sur la facturation
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.grey.shade700,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Cette mise à niveau sera effective immédiatement et vous serez facturé au prorata.",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Message d'erreur éventuel
                          if (_errorMessage.isNotEmpty) ...[
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        // Si aucune mise à niveau n'est sélectionnée
                        if (_selectedMemberCount <= _maxMemberCount) ...[
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 40,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Veuillez sélectionner un forfait supérieur à votre forfait actuel ($_maxMemberCount membres).",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bouton d'action fixe en bas
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_isPurchasing ||
                              _selectedMemberCount <= _maxMemberCount)
                          ? null
                          : _upgradeSubscription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isPurchasing
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.0,
                              ),
                            )
                          : Text(
                              "METTRE À NIVEAU",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
