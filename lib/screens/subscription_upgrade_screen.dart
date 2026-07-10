import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  // Une abonnée Stripe (inscription web) qui déclenchait un achat In-App
  // Purchase depuis cet écran se serait retrouvée avec 2 abonnements
  // facturés en parallèle (Stripe jamais résilié + nouvel achat Apple/
  // Google) — on route donc vers upgradeStripeSubscription à la place.
  bool _isStripeSubscription = false;

  // ✅ Services unifiés pour la gestion des abonnements
  final UnifiedSubscriptionService _subscriptionService =
      UnifiedSubscriptionService.instance;
  StreamSubscription<SubscriptionInfo>? _subscriptionUpdates;
  StreamSubscription<String>? _subscriptionErrors;
  bool _upgradeCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadCurrentSubscriptionData();
  }

  @override
  void dispose() {
    _subscriptionUpdates?.cancel();
    _subscriptionErrors?.cancel();
    super.dispose();
  }

  // ✅ NOUVELLE MÉTHODE : Initialiser les services d'abonnement
  Future<void> _initializeServices() async {
    try {
      // Initialiser le service d'abonnement
      await SubscriptionService.initialize();

      // Initialiser le service unifié
      await _subscriptionService.initialize();

      _subscriptionUpdates =
          _subscriptionService.subscriptionUpdates.listen(
        _handleSubscriptionUpdate,
        onError: (_) {},
      );

      _subscriptionErrors = _subscriptionService.errors.listen((error) {
        if (!mounted) return;
        setState(() {
          _isPurchasing = false;
          _errorMessage = "Erreur d'achat: $error";
        });
        _showSnackBar("Erreur d'achat: $error", Colors.red);
      });

      print('✅ Services d\'abonnement initialisés (upgrade)');
    } catch (e) {
      print('❌ Erreur initialisation services: $e');
    }
  }

  void _handleSubscriptionUpdate(SubscriptionInfo info) async {
    if (!mounted) return;

    switch (info.status) {
      case SubscriptionStatus.pending:
        setState(() {
          _isPurchasing = true;
          _errorMessage = '';
        });
        break;
      case SubscriptionStatus.purchased:
      case SubscriptionStatus.restored:
        final int newCount =
            _memberCountForProductId(info.productId) ?? _selectedMemberCount;
        await _finalizeUpgrade(newCount, info.productId);
        break;
      case SubscriptionStatus.error:
        setState(() {
          _isPurchasing = false;
          _errorMessage = "Erreur d'achat";
        });
        _showSnackBar(
          "Erreur lors de la mise à niveau. Veuillez réessayer.",
          Colors.red,
        );
        break;
      case SubscriptionStatus.cancelled:
      case SubscriptionStatus.expired:
        setState(() {
          _isPurchasing = false;
        });
        break;
      case SubscriptionStatus.unknown:
        break;
    }
  }

  Future<void> _finalizeUpgrade(int newMemberCount, String productId) async {
    if (_upgradeCompleted) {
      return;
    }
    _upgradeCompleted = true;

    final int previousMemberPlan = _maxMemberCount;

    await _syncStructureAfterUpgrade(newMemberCount);

    setState(() {
      _isPurchasing = false;
      _maxMemberCount = newMemberCount;
      _newPrice = _getPriceForMembers(newMemberCount);
    });

    final String structureId = await _getStructureId();
    if (!mounted) return;

    context.go('/upgrade-confirmed', extra: {
      'structureType': 'MAM',
      'structureId': structureId,
      'memberCount': newMemberCount >= 4 ? 4 : newMemberCount,
      'oldMemberCount': previousMemberPlan,
      'productId': productId,
      'priceDisplay': _getPriceForMembers(newMemberCount),
    });
  }

  /// Mise à niveau pour une abonnée Stripe : modifie l'abonnement Stripe
  /// EXISTANT (changement de prix avec proration) via la Cloud Function
  /// upgradeStripeSubscription, qui fait aussi la synchronisation Firestore
  /// côté serveur — pas besoin d'appeler _syncStructureAfterUpgrade ici.
  Future<void> _upgradeViaStripe(int targetCount) async {
    if (_upgradeCompleted) return;

    final String tier = targetCount >= 4 ? '4+' : '2-3';
    final int newMemberCount = targetCount >= 4 ? 4 : 3;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('upgradeStripeSubscription');
      await callable.call(<String, dynamic>{'tier': tier});

      _upgradeCompleted = true;
      final int previousMemberPlan = _maxMemberCount;

      setState(() {
        _isPurchasing = false;
        _maxMemberCount = newMemberCount;
        _newPrice = _getPriceForMembers(newMemberCount);
      });

      final String structureId = await _getStructureId();
      if (!mounted) return;

      context.go('/upgrade-confirmed', extra: {
        'structureType': 'MAM',
        'structureId': structureId,
        'memberCount': newMemberCount,
        'oldMemberCount': previousMemberPlan,
        'productId': 'stripe_$tier',
        'priceDisplay': _getPriceForMembers(newMemberCount),
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isPurchasing = false;
        _errorMessage = e.message ?? 'Erreur lors de la mise à niveau Stripe';
      });
      _showSnackBar(_errorMessage, Colors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPurchasing = false;
        _errorMessage = "Erreur lors de la mise à niveau: $e";
      });
      _showSnackBar(_errorMessage, Colors.red);
    }
  }

  Future<void> _syncStructureAfterUpgrade(int newMemberCount) async {
    try {
      final String structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      final int maxAllowed = newMemberCount >= 4 ? 99 : newMemberCount;

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .set(
        {
          // Sans ce champ, une Assistante Maternelle solo qui vient de
          // passer en MAM restait techniquement "AssistanteMaternelle" —
          // payante pour un forfait MAM mais invisible comme telle partout
          // ailleurs dans l'app (gestion des membres, dashboard, etc).
          'structureType': 'MAM',
          'maxMemberCount': maxAllowed,
          'subscriptionActive': true,
          'subscriptionStatus': 'active',
          'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
          // Sans ces 2 champs, le prix affiché ailleurs dans l'app
          // (résumé d'abonnement, etc.) restait celui de l'ancien forfait.
          'currentPriceAmount': _priceAmountForMembers(newMemberCount),
          'currentPriceDisplay': _getPriceForMembers(newMemberCount),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('⚠️ Impossible de synchroniser la structure après upgrade: $e');
    }
  }

  int? _memberCountForProductId(String productId) {
    final String normalized = productId.toLowerCase();
    if (normalized.contains('mam_4') || normalized.contains('mam4')) {
      return 4;
    }
    if (normalized.contains('mam_3') || normalized.contains('mam3')) {
      return 3;
    }
    if (normalized.contains('mam_2') || normalized.contains('mam2')) {
      return 2;
    }
    return null;
  }

  SubscriptionPlan _planForMemberCount(int memberCount) {
    if (memberCount >= 4) {
      return SubscriptionPlan.mam4PlusMembers;
    }
    if (memberCount == 3) {
      return SubscriptionPlan.mam3Members;
    }
    return SubscriptionPlan.mam2Members;
  }

  String _getPlatformProductIdForMembers(int memberCount) {
    if (Platform.isIOS) {
      if (memberCount >= 4) {
        return 'com.beylet.poppinsApp.subscription.mam_4_membres';
      }
      if (memberCount == 3) {
        return 'com.beylet.poppinsApp.subscription.mam_3_membres';
      }
      return 'com.beylet.poppinsApp.subscription.mam_2_membres';
    } else {
      if (memberCount >= 4) {
        return 'abonnement_mam4';
      }
      if (memberCount == 3) {
        return 'abonnement_mam3';
      }
      return 'abonnement_mam2';
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _applyDevUpgrade(int newMemberCount, String productId) async {
    final int previousMemberPlan = _maxMemberCount;
    _upgradeCompleted = true;
    final String structureId = await _getStructureId();
    await _syncStructureAfterUpgrade(newMemberCount);

    try {
      final QuerySnapshot<Map<String, dynamic>> subscriptionQuery =
          await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('structureId', isEqualTo: structureId)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();

      final Map<String, dynamic> updates = {
        'memberCount': newMemberCount,
        'productId': 'dev_$productId',
        'purchaseId': 'dev_${DateTime.now().millisecondsSinceEpoch}',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (subscriptionQuery.docs.isNotEmpty) {
        await subscriptionQuery.docs.first.reference.update(updates);
      } else {
        await FirebaseFirestore.instance.collection('subscriptions').add({
          ...updates,
          'structureId': structureId,
          'structureType': 'MAM',
          'status': 'active',
          'purchaseDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('⚠️ Impossible de mettre à jour la collection subscriptions en mode dev: $e');
    }

    setState(() {
      _isPurchasing = false;
      _maxMemberCount = newMemberCount;
      _newPrice = _getPriceForMembers(newMemberCount);
    });

    if (!mounted) return;

    context.go('/upgrade-confirmed', extra: {
      'structureType': 'MAM',
      'structureId': structureId,
      'memberCount': newMemberCount >= 4 ? 4 : newMemberCount,
      'oldMemberCount': previousMemberPlan,
      'productId': productId,
      'isDev': true,
      'priceDisplay': _getPriceForMembers(newMemberCount),
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
      final String platform = (data['subscriptionPlatform'] ??
              data['subscriptionSource'] ??
              '')
          .toString()
          .toLowerCase();
      _isStripeSubscription = platform == 'stripe';

      // Cet écran sert à la fois à convertir une Assistante Maternelle solo
      // en MAM, et à augmenter le nombre de membres d'une MAM existante — il
      // ne doit donc JAMAIS bloquer l'accès pour les structures qui ne sont
      // pas encore des MAM (c'était le cas précédemment et empêchait toute
      // conversion, l'écran étant la seule porte d'entrée pour ce faire).
      bool isMam = _structureType == 'MAM';

      // ✅ CORRECTION : MAM minimum 2 membres — mais on ne force ce minimum
      // que pour une MAM existante dont la donnée serait corrompue. Pour une
      // Assistante Maternelle solo pas encore convertie, _maxMemberCount doit
      // rester à sa vraie valeur actuelle (1) : forcer 2 avant même qu'elle
      // ait choisi/payé un forfait verrouillait à tort le choix "2 membres"
      // comme si c'était déjà son forfait en cours.
      if (data.containsKey('maxMemberCount')) {
        _maxMemberCount = data['maxMemberCount'] ?? (isMam ? 2 : 1);
        if (isMam && _maxMemberCount < 2) {
          _maxMemberCount = 2;
          // Corriger en base de données (uniquement pour une MAM existante)
          await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .update({'maxMemberCount': 2});
        }
      } else if (data.containsKey('subscription') &&
          data['subscription'] != null) {
        _maxMemberCount =
            data['subscription']['maxMembers'] ?? (isMam ? 2 : 1);
        if (isMam && _maxMemberCount < 2) _maxMemberCount = 2;
      } else {
        _maxMemberCount = isMam ? 2 : 1;
        if (isMam) {
          // Mettre à jour en base (uniquement pour une MAM existante)
          await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .update({'maxMemberCount': 2});
        }
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
  // 1 membre (Assistante Maternelle solo) = 3,99€ ; 2 ou 3 membres = 9,99€ ;
  // 4 membres et + = 14,99€. Manquait le cas "1 membre" (affichait 9,99€ à
  // tort), invisible tant que l'écran était inaccessible aux comptes solo.
  String _getPriceForMembers(int memberCount) {
    if (memberCount <= 1) {
      return '3,99 € / mois';
    }
    if (memberCount <= 3) {
      return '9,99 € / mois';
    }
    return '14,99 € / mois';
  }

  double _priceAmountForMembers(int memberCount) {
    if (memberCount <= 1) return 3.99;
    if (memberCount <= 3) return 9.99;
    return 14.99;
  }

  // Libellé d'affichage par palier (2 et 3 membres ont le même prix, donc le
  // même palier "2-3" — cf. _buildTierButton).
  String _tierLabel(int memberCount) {
    if (memberCount <= 1) return '1 membre';
    if (memberCount <= 3) return '2-3 membres';
    return '4 membres et +';
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

  Future<void> _upgradeSubscription() async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = '';
      _upgradeCompleted = false;
    });

    try {
      final int targetCount = _selectedMemberCount < 2 ? 2 : _selectedMemberCount;
      print('🛒 Tentative de mise à niveau vers $targetCount membre(s)');

      if (_isStripeSubscription) {
        // Abonnée Stripe : on modifie l'abonnement existant côté serveur au
        // lieu de déclencher un achat In-App (qui créerait un 2e abonnement
        // parallèle, jamais résilié).
        await _upgradeViaStripe(targetCount);
        return;
      }

      if (SubscriptionService.isInDevMode) {
        print('🧪 MODE DEV: Simulation d\'achat');

        await Future.delayed(const Duration(seconds: 1));

        final String productId =
            _getPlatformProductIdForMembers(targetCount);
        final Map<String, dynamic> simulated =
            await SubscriptionService.simulateDevPurchaseSuccess(productId);

        final int simulatedCount = simulated['memberCount'] is int
            ? simulated['memberCount'] as int
            : targetCount;

        await _applyDevUpgrade(simulatedCount, productId);

        return;
      }

      final SubscriptionPlan plan = _planForMemberCount(targetCount);
      final bool launched =
          await _subscriptionService.purchaseSubscription(plan);

      if (!launched) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = 'Impossible de lancer l\'achat';
        });
        _showSnackBar(
          "Impossible de lancer l'abonnement. Veuillez réessayer.",
          Colors.red,
        );
      } else {
        print('🚀 Mise à niveau lancée pour le plan $plan');
      }
    } catch (e) {
      setState(() {
        _isPurchasing = false;
        _errorMessage = "Erreur lors de la mise à niveau: ${e.toString()}";
      });
      _showSnackBar(
        "Erreur lors de la mise à niveau: $e",
        Colors.red,
      );
    }
  }
  // 2 forfaits MAM seulement (pas 3) : "2 membres" et "3 membres" ont
  // exactement le même prix (9,99€), donc les proposer comme 2 boutons
  // distincts n'apporte rien et prête à confusion. "value" (3) est le
  // nombre de membres utilisé pour le produit/prix réel acheté (identique
  // pour 2 ou 3 membres), "minForTier" (2) sert uniquement à savoir si ce
  // palier est déjà atteint.
  Widget _buildTierButton({
    required String label,
    required int value,
    required int minForTier,
    int? maxForTier,
    required bool isSelected,
    required Color color,
  }) {
    final bool isCurrent = _maxMemberCount >= minForTier &&
        (maxForTier == null || _maxMemberCount <= maxForTier);
    final bool isDisabled = _maxMemberCount >= minForTier;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedMemberCount = value;
                _newPrice = _getPriceForMembers(value);
              });
            },
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isCurrent ? Colors.blue.shade50 : Colors.grey.shade200)
              : (isSelected ? color : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? (isCurrent ? Colors.blue.shade300 : Colors.grey.shade300)
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
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDisabled
                    ? (isCurrent ? Colors.blue.shade700 : Colors.grey)
                    : (isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "membres",
              style: TextStyle(
                fontSize: 12,
                color: isDisabled
                    ? (isCurrent ? Colors.blue.shade700 : Colors.grey)
                    : (isSelected ? Colors.white : Colors.grey.shade700),
              ),
            ),
            SizedBox(height: 4),
            Text(
              _getPriceForMembers(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? (isCurrent ? Colors.blue.shade700 : Colors.grey)
                    : (isSelected ? Colors.white : color),
              ),
            ),
            if (isCurrent) ...[
              SizedBox(height: 4),
              Text(
                "actuel",
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.blue.shade700,
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
                                  _buildTierButton(
                                    label: "2-3",
                                    value: 3,
                                    minForTier: 2,
                                    maxForTier: 3,
                                    isSelected: _selectedMemberCount >= 2 &&
                                        _selectedMemberCount <= 3,
                                    color: primaryBlue,
                                  ),
                                  _buildTierButton(
                                    label: "4+",
                                    value: 4,
                                    minForTier: 4,
                                    isSelected: _selectedMemberCount >= 4,
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
                                            _tierLabel(_maxMemberCount),
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
                                            _tierLabel(_selectedMemberCount),
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
