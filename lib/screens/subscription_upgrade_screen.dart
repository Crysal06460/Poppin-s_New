import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'dart:io';

// ✅ IMPORTS AJOUTÉS pour les services d'abonnement
import '../services/subscription_service.dart';
import '../services/unified_subscription_service.dart';

class SubscriptionUpgradeScreen extends StatefulWidget {
  const SubscriptionUpgradeScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionUpgradeScreenState createState() =>
      _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState extends State<SubscriptionUpgradeScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // Pour erreurs uniquement
  static const Color primaryBlue = Color(0xFF3D9DF2); // COULEUR PRINCIPALE
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

  // ✅ AJOUTÉ : Stream subscription pour écouter les achats
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadCurrentSubscriptionData();
  }

  @override
  void dispose() {
    // ✅ AJOUTÉ : Nettoyer les listeners
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  // ✅ NOUVELLE MÉTHODE : Initialiser les services d'abonnement
  Future<void> _initializeServices() async {
    try {
      // Initialiser le service d'abonnement
      await SubscriptionService.initialize();

      // Initialiser le service unifié
      await UnifiedSubscriptionService.instance.initialize();

      // ✅ ÉCOUTER LES MISES À JOUR D'ACHAT
      _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdate,
        onError: (error) {
          setState(() {
            _isPurchasing = false;
            _errorMessage = "Erreur d'achat: $error";
          });
        },
      );

      print('✅ Services d\'abonnement initialisés');
    } catch (e) {
      print('❌ Erreur initialisation services: $e');
    }
  }

  // ✅ NOUVELLE MÉTHODE : Traiter les mises à jour d'achat
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      print('🛒 Mise à jour achat: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          _handlePurchaseSuccess(purchase);
          break;
        case PurchaseStatus.error:
          _handlePurchaseError(purchase.error?.message ?? 'Erreur inconnue');
          break;
        case PurchaseStatus.canceled:
          _handlePurchaseCanceled();
          break;
        case PurchaseStatus.pending:
          // L'achat est en attente (payment deferral sur iOS)
          print('⏳ Achat en attente: ${purchase.productID}');
          break;
        case PurchaseStatus.restored:
          // Achat restauré
          _handlePurchaseSuccess(purchase);
          break;
      }

      // Finaliser la transaction
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  // ✅ NOUVELLE MÉTHODE : Traiter un achat réussi
  Future<void> _handlePurchaseSuccess(PurchaseDetails purchase) async {
    try {
      setState(() {
        _isPurchasing = false;
      });

      // Mettre à jour Firestore avec le nouvel abonnement
      await _updateFirestoreSubscription(purchase);

      // ✅ REDIRECTION VERS L'ÉCRAN DE CONFIRMATION
      context.go('/upgrade-confirmed', extra: {
        'structureType': 'MAM',
        'structureId': await _getStructureId(),
        'memberCount': _selectedMemberCount,
        'oldMemberCount': _maxMemberCount,
        'purchaseId': purchase.purchaseID,
        'productId': purchase.productID,
      });

      print('✅ Achat réussi et Firestore mis à jour');
    } catch (e) {
      setState(() {
        _isPurchasing = false;
        _errorMessage = "Erreur lors de la finalisation: $e";
      });
    }
  }

  // ✅ NOUVELLE MÉTHODE : Traiter une erreur d'achat
  void _handlePurchaseError(String error) {
    setState(() {
      _isPurchasing = false;
      _errorMessage = "Erreur d'achat: $error";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Erreur d'achat: $error"),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ✅ NOUVELLE MÉTHODE : Traiter un achat annulé
  void _handlePurchaseCanceled() {
    setState(() {
      _isPurchasing = false;
      _errorMessage = "";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Achat annulé"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ✅ MÉTHODE MODIFIÉE : Mettre à jour Firestore après achat réussi
  Future<void> _updateFirestoreSubscription(PurchaseDetails purchase) async {
    final String structureId = await _getStructureId();

    // 1. Mettre à jour l'abonnement dans la collection subscriptions
    final subscriptionQuery = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('structureId', isEqualTo: structureId)
        .where('status', isEqualTo: 'active')
        .get();

    if (subscriptionQuery.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscriptionQuery.docs.first.id)
          .update({
        'memberCount': _selectedMemberCount,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'purchaseDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': structureId,
        'structureType': 'MAM',
        'memberCount': _selectedMemberCount,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'purchaseDate': FieldValue.serverTimestamp(),
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
      'subscriptionActive': true,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
    });
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

      // ✅ CORRECTION : MAM minimum 2 membres
      if (data.containsKey('maxMemberCount')) {
        _maxMemberCount = data['maxMemberCount'] ?? 2;
        // ✅ S'assurer que c'est au minimum 2 pour une MAM
        if (_maxMemberCount < 2) {
          _maxMemberCount = 2;
          // Corriger en base de données
          await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .update({'maxMemberCount': 2});
        }
      } else if (data.containsKey('subscription') &&
          data['subscription'] != null) {
        _maxMemberCount = data['subscription']['maxMembers'] ?? 2;
        // ✅ S'assurer que c'est au minimum 2 pour une MAM
        if (_maxMemberCount < 2) _maxMemberCount = 2;
      } else {
        _maxMemberCount = 2; // ✅ MINIMUM 2 pour MAM
        // Mettre à jour en base
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .update({'maxMemberCount': 2});
      }

      // Compter le nombre actuel de membres
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .get();

      _currentMemberCount = membersSnapshot.docs.length;
      // ✅ S'assurer qu'on a au minimum 1 membre même si la collection est vide
      if (_currentMemberCount < 1) _currentMemberCount = 1;

      // Déterminer le prix actuel
      _currentPrice = _getPriceForMembers(_maxMemberCount);

      // ✅ CORRECTION : Proposer le niveau d'abonnement suivant approprié
      _selectedMemberCount = _maxMemberCount < 4 ? _maxMemberCount + 1 : 4;
      _newPrice = _getPriceForMembers(_selectedMemberCount);

      print(
          "💰 MAM - Abonnement actuel: $_maxMemberCount membres ($_currentPrice)");
      print("👥 MAM - Membres actuels: $_currentMemberCount");
      print(
          "🔄 MAM - Proposition mise à niveau: $_selectedMemberCount membres ($_newPrice)");

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
        return '19,99 € / mois';
      case 3:
        return '24,99 € / mois';
      case 4:
        return '29,99 € / mois';
      default:
        // ✅ CORRECTION : Si < 2, renvoyer le prix pour 2 membres
        if (memberCount < 2) return '19,99 € / mois';
        return '29,99 € / mois'; // Pour > 4, utiliser le prix maximum
    }
  }

  // ✅ OBTENIR L'ID PRODUIT POUR LES ACHATS IN-APP
  String _getProductIdForMembers(int memberCount) {
    // ✅ CORRECTION : Gérer le cas où memberCount < 2
    int actualMemberCount = memberCount < 2 ? 2 : memberCount;

    if (Platform.isIOS) {
      // IDs iOS (définis dans subscription_service.dart)
      switch (actualMemberCount) {
        case 2:
          return 'com.beylet.poppinsApp.subscription.mam_2_membres';
        case 3:
          return 'com.beylet.poppinsApp.subscription.mam_3_membres';
        case 4:
          return 'com.beylet.poppinsApp.subscription.mam_4_membres';
        default:
          return 'com.beylet.poppinsApp.subscription.mam_2_membres';
      }
    } else {
      // IDs Android (définis dans subscription_service.dart)
      switch (actualMemberCount) {
        case 2:
          return 'abonnement_mam2';
        case 3:
          return 'abonnement_mam3';
        case 4:
          return 'abonnement_mam4';
        default:
          return 'abonnement_mam2';
      }
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

  // ✅ MÉTHODE COMPLÈTEMENT RÉÉCRITE : Vraie mise à niveau avec Apple Store/Google Play
  Future<void> _upgradeSubscription() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = '';
    });

    try {
      // ✅ OBTENIR L'ID PRODUIT CORRECT
      final String productId = _getProductIdForMembers(_selectedMemberCount);
      print('🛒 Tentative d\'achat du produit: $productId');

      // ✅ VÉRIFIER SI ON EST EN MODE DÉVELOPPEMENT
      if (SubscriptionService.isInDevMode) {
        print('🧪 MODE DEV: Simulation d\'achat');

        // Simuler un délai d'achat
        await Future.delayed(Duration(seconds: 2));

        // Simuler un achat réussi
        final fakeSuccess =
            await SubscriptionService.simulateDevPurchaseSuccess(productId);

        // Mettre à jour Firestore directement en mode dev
        await _updateFirestoreAfterDevPurchase();

        // Rediriger vers la confirmation
        context.go('/upgrade-confirmed', extra: {
          'structureType': 'MAM',
          'structureId': await _getStructureId(),
          'memberCount': _selectedMemberCount,
          'oldMemberCount': _maxMemberCount,
          'isDev': true,
        });

        setState(() {
          _isPurchasing = false;
        });

        return;
      }

      // ✅ MODE PRODUCTION : VRAI ACHAT via Apple Store/Google Play
      final InAppPurchase inAppPurchase = InAppPurchase.instance;

      // Vérifier que les achats sont disponibles
      final bool isAvailable = await inAppPurchase.isAvailable();
      if (!isAvailable) {
        throw Exception('Achats intégrés non disponibles sur cet appareil');
      }

      // Récupérer les détails du produit
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails({productId});

      if (response.error != null) {
        throw Exception(
            'Erreur lors de la récupération du produit: ${response.error?.message}');
      }

      if (response.productDetails.isEmpty) {
        throw Exception('Produit non trouvé: $productId');
      }

      // ✅ LANCER L'ACHAT RÉEL
      final ProductDetails productDetails = response.productDetails.first;
      print(
          '✅ Produit trouvé: ${productDetails.title} - ${productDetails.price}');

      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: productDetails);

      // 🚀 ACHAT RÉEL via Apple Store/Google Play
      final bool launched =
          await inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!launched) {
        throw Exception('Impossible de lancer l\'interface d\'achat');
      }

      print('🚀 Achat lancé - En attente de la réponse de l\'utilisateur...');
      // Le résultat sera traité par _handlePurchaseUpdate()
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

  // ✅ NOUVELLE MÉTHODE : Mise à jour Firestore en mode développement
  Future<void> _updateFirestoreAfterDevPurchase() async {
    final String structureId = await _getStructureId();

    // Mettre à jour ou créer l'abonnement
    final subscriptionQuery = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('structureId', isEqualTo: structureId)
        .where('status', isEqualTo: 'active')
        .get();

    if (subscriptionQuery.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscriptionQuery.docs.first.id)
          .update({
        'memberCount': _selectedMemberCount,
        'productId': 'dev_${_getProductIdForMembers(_selectedMemberCount)}',
        'purchaseId': 'dev_${DateTime.now().millisecondsSinceEpoch}',
        'purchaseDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': structureId,
        'structureType': 'MAM',
        'memberCount': _selectedMemberCount,
        'productId': 'dev_${_getProductIdForMembers(_selectedMemberCount)}',
        'purchaseId': 'dev_${DateTime.now().millisecondsSinceEpoch}',
        'purchaseDate': FieldValue.serverTimestamp(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Mettre à jour la structure
    await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .update({
      'maxMemberCount': _selectedMemberCount,
      'subscriptionActive': true,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ CORRECTION - SEULE VERSION de la méthode _buildMemberCountButton
  Widget _buildMemberCountButton({
    required int count,
    required bool isSelected,
    required Color color,
  }) {
    // ✅ CORRECTION : Pour une MAM, désactiver les options inférieures OU ÉGALES au nombre actuel
    // MAIS s'assurer qu'on ne peut pas descendre en dessous de 2
    bool isDisabled = count <= _maxMemberCount;

    // ✅ AJOUT : Indiquer si c'est l'abonnement actuel
    bool isCurrent = count == _maxMemberCount;

    // ✅ AJOUT : Validation pour MAM (minimum 2 membres)
    bool isValidForMAM = count >= 2;

    return GestureDetector(
      onTap: (isDisabled || !isValidForMAM)
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
          color: !isValidForMAM
              ? Colors.grey.shade200
              : isDisabled
                  ? (isCurrent ? Colors.blue.shade50 : Colors.grey.shade200)
                  : (isSelected ? color : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !isValidForMAM
                ? Colors.grey.shade300
                : isDisabled
                    ? (isCurrent ? Colors.blue.shade300 : Colors.grey.shade300)
                    : (isSelected ? color : Colors.grey.shade300),
            width: 1.5,
          ),
          boxShadow: isSelected && !isDisabled && isValidForMAM
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
                color: !isValidForMAM
                    ? Colors.grey.shade400
                    : isDisabled
                        ? (isCurrent ? Colors.blue.shade700 : Colors.grey)
                        : (isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "membres",
              style: TextStyle(
                fontSize: 12,
                color: !isValidForMAM
                    ? Colors.grey.shade400
                    : isDisabled
                        ? (isCurrent ? Colors.blue.shade700 : Colors.grey)
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
                  color: isSelected
                      ? Colors.white.withOpacity(0.8)
                      : Colors.blue.shade700,
                ),
              ),
            ],
            // ✅ AJOUT : Indiquer si en dessous du minimum MAM
            if (!isValidForMAM) ...[
              SizedBox(height: 4),
              Text(
                "min. 2",
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
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
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryBlue),
            )
          : Column(
              children: [
                // En-tête avec couleur BLEUE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  decoration: BoxDecoration(
                    color: primaryBlue,
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
                                  // ✅ CORRECTION : Affichage correct du nombre de membres
                                  "$_maxMemberCount membre${_maxMemberCount > 1 ? 's' : ''}",
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
                            // ✅ AJOUT : Information sur les membres actuels vs autorisés
                            if (_currentMemberCount != _maxMemberCount) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$_currentMemberCount membre${_currentMemberCount > 1 ? 's' : ''} sur $_maxMemberCount autorisé${_maxMemberCount > 1 ? 's' : ''}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
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
                            color: primaryBlue,
                          ),
                        ),
                        SizedBox(height: 20),

                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightBlue,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: primaryBlue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Nombre d'assistant(e)s maternel(le)s dans votre MAM",
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
                                      color: primaryBlue,
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
                              border: Border.all(color: primaryBlue),
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
                                    color: primaryBlue,
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
                                      color: primaryBlue,
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
                                              color: primaryBlue,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _newPrice,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: primaryBlue,
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

                                // ✅ INDICATEUR DE MODE DÉVELOPPEMENT
                                if (SubscriptionService.isInDevMode) ...[
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.developer_mode,
                                          color: Colors.orange.shade700,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Mode développement activé - Aucun achat réel ne sera effectué",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                  // ✅ CORRECTION : Message plus précis
                                  "Veuillez sélectionner un forfait supérieur à votre forfait actuel ($_maxMemberCount membres).\n\n" +
                                      "Pour une MAM, l'abonnement minimum est de 2 membres.",
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
                        backgroundColor: primaryBlue,
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
                              SubscriptionService.isInDevMode
                                  ? "SIMULER MISE À NIVEAU"
                                  : "METTRE À NIVEAU",
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
