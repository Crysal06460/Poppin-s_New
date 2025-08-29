// lib/screens/pricing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
// Import du nouveau service unifié
import '../services/unified_subscription_service.dart';
import 'dart:async';

class PricingScreen extends StatefulWidget {
  final String structureType;
  final int mamMembersCount;

  const PricingScreen({
    Key? key,
    required this.structureType,
    this.mamMembersCount = 2,
  }) : super(key: key);

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  // Service unifié
  final UnifiedSubscriptionService _subscriptionService =
      UnifiedSubscriptionService.instance;

  // État
  bool _isLoading = true;
  bool _isPurchasing = false;
  List<SubscriptionInfo> _availableSubscriptions = [];
  SubscriptionInfo? _activeSubscription;
  String _errorMessage = '';

  // Pour la sélection du nombre de membres MAM
  int _selectedMamMembers = 2;

  @override
  void initState() {
    super.initState();
    // Initialiser le nombre de membres sélectionné avec la valeur passée
    _selectedMamMembers = widget.mamMembersCount;
    _initializeSubscriptions();
  }

  /// Couleurs officielles de l'application
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);
  static const Color lightGray = Color(0xFFDFE9F2);
  static const Color cyan = Color(0xFF05C7F2);
  static const Color orange = Color(0xFFF2B705);

  /// Initialise les abonnements
  Future<void> _initializeSubscriptions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Initialiser le service
      await _subscriptionService.initialize();

      // ✅ AJOUT CRITIQUE : Vérifier d'abord si déjà abonné
      final activeSubscription =
          await _subscriptionService.getActiveSubscription();
      if (activeSubscription != null) {
        print('✅ Utilisateur déjà abonné, redirection vers confirmation');
        // Rediriger directement vers l'écran de confirmation
        _redirectToConfirmationScreen();
        return;
      }

      // Écouter les mises à jour
      _subscriptionService.subscriptionUpdates.listen(
        _handleSubscriptionUpdate,
        onError: (error) {
          setState(() {
            _errorMessage = error.toString();
          });
        },
      );

      _subscriptionService.errors.listen(
        (error) {
          setState(() {
            _errorMessage = error;
          });
          _showErrorDialog(error);
        },
      );

      // Charger les produits et vérifier les abonnements actifs
      await _loadSubscriptions();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur d\'initialisation: $e';
        _isLoading = false;
      });
      _showErrorDialog(_errorMessage);
    }
  }
// 🔧 AJOUTEZ cette méthode manquante dans pricing_screen.dart
// Placez-la après la méthode _handleSubscriptionUpdate()

  /// Charge les abonnements disponibles
  Future<void> _loadSubscriptions() async {
    try {
      // Récupérer les produits disponibles
      final subscriptions =
          await _subscriptionService.getAvailableSubscriptions();

      // ✅ TOUJOURS vérifier l'abonnement actif (même en debug)
      SubscriptionInfo? activeSubscription;
      try {
        activeSubscription = await _subscriptionService.getActiveSubscription();
        print(
            '🔍 Vérification abonnement actif: ${activeSubscription?.productId}');
      } catch (e) {
        print('⚠️ Erreur vérification abonnement actif: $e');
      }

      setState(() {
        _availableSubscriptions = subscriptions;
        _activeSubscription = activeSubscription;
        _isLoading = false;
      });

      print('📱 ${subscriptions.length} abonnements chargés');
      if (activeSubscription != null) {
        print('✅ Abonnement actif détecté: ${activeSubscription.productId}');
        // ✅ AJOUT : Si abonnement trouvé pendant le chargement, rediriger
        _redirectToConfirmationScreen();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  /// Gère les mises à jour d'abonnement
  void _handleSubscriptionUpdate(SubscriptionInfo subscription) {
    print('📥 Mise à jour abonnement reçue: ${subscription.status}');

    setState(() {
      if (subscription.status == SubscriptionStatus.purchased) {
        _activeSubscription = subscription;
        _isPurchasing = false;

        print('✅ Achat réussi, redirection automatique vers confirmation');
        _redirectToConfirmationScreen();
      } else if (subscription.status == SubscriptionStatus.error) {
        _isPurchasing = false;
        _showErrorDialog('Erreur d\'achat');
      } else if (subscription.status == SubscriptionStatus.pending) {
        print('⏳ Achat en cours...');
        // Garder _isPurchasing = true
      }
      // ✅ SUPPRIMÉ : SubscriptionStatus.canceled n'existe pas
      // Les annulations sont gérées automatiquement par le système
    });
  }

  /// Détermine le plan selon la configuration
  SubscriptionPlan _getCurrentPlan() {
    if (widget.structureType == 'assistante_maternelle') {
      return SubscriptionPlan.assistantMaternel;
    } else {
      switch (_selectedMamMembers) {
        case 2:
          return SubscriptionPlan.mam2Members;
        case 3:
          return SubscriptionPlan.mam3Members;
        case 4:
          return SubscriptionPlan.mam4Members;
        default:
          return SubscriptionPlan.mam2Members;
      }
    }
  }

  /// Achète un abonnement
  Future<void> _purchaseSubscription() async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = '';
    });

    try {
      // ✅ AJOUT : Vérification préalable
      final existingSubscription =
          await _subscriptionService.getActiveSubscription();
      if (existingSubscription != null) {
        print('✅ Abonnement déjà actif détecté');
        setState(() {
          _isPurchasing = false;
          _activeSubscription = existingSubscription;
        });
        _redirectToConfirmationScreen();
        return;
      }

      final plan = _getCurrentPlan();
      final success = await _subscriptionService.purchaseSubscription(plan);

      if (!success) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = 'Échec de l\'achat';
        });
        _showErrorDialog('L\'achat n\'a pas pu être finalisé');
        return;
      }

      // ✅ AJOUT CRITIQUE : Timeout pour débloquer l'UI
      Timer(Duration(seconds: 3), () {
        if (_isPurchasing) {
          print('⏰ Timeout : vérification manuelle du statut d\'achat');
          _checkPurchaseStatus();
        }
      });
    } catch (e) {
      setState(() {
        _isPurchasing = false;
        _errorMessage = 'Erreur: $e';
      });
      _showErrorDialog('Erreur lors de l\'achat: $e');
    }
  }

  Future<void> _checkPurchaseStatus() async {
    try {
      final activeSubscription =
          await _subscriptionService.getActiveSubscription();
      if (activeSubscription != null) {
        setState(() {
          _isPurchasing = false;
          _activeSubscription = activeSubscription;
        });
        print('✅ Abonnement détecté via vérification manuelle');
        _redirectToConfirmationScreen();
      } else {
        // Encore en cours ou échec
        final hasActive = await _subscriptionService.hasActiveSubscription();
        if (hasActive) {
          setState(() {
            _isPurchasing = false;
          });
          print('✅ Abonnement actif confirmé');
          _redirectToConfirmationScreen();
        } else if (_isPurchasing) {
          // Toujours en cours après timeout
          setState(() {
            _isPurchasing = false;
            _errorMessage = 'Vérification en cours...';
          });
        }
      }
    } catch (e) {
      print('❌ Erreur vérification statut: $e');
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  /// Restaure les achats
  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _subscriptionService.restorePurchases();
      await _loadSubscriptions();

      if (_activeSubscription != null) {
        // ✅ CORRECTION : Redirection directe au lieu de dialog
        print('✅ Abonnement restauré avec succès !');
        _redirectToConfirmationScreen();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Aucun abonnement à restaurer');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de restauration: $e';
        _isLoading = false;
      });
      _showErrorDialog('Erreur lors de la restauration: $e');
    }
  }

  void _showSuccessDialog([String? message]) {
    print('✅ ${message ?? "Abonnement activé avec succès !"}');
    _redirectToConfirmationScreen();
  }

  void _redirectToConfirmationScreen() {
    final bool isAssMat = widget.structureType == 'assistante_maternelle';

    final String structureType = isAssMat ? 'assistante_maternelle' : 'MAM';
    final int memberCount = isAssMat ? 1 : _selectedMamMembers;
    final double priceAmount = isAssMat
        ? 8.99
        : (_selectedMamMembers == 2
            ? 19.99
            : (_selectedMamMembers == 3 ? 24.99 : 29.99));
    final String priceDisplay = isAssMat
        ? '8,99 € / mois'
        : (_selectedMamMembers == 2
            ? '19,99 € / mois'
            : (_selectedMamMembers == 3 ? '24,99 € / mois' : '29,99 € / mois'));

    context.go('/subscription-confirmed', extra: {
      'structureType': structureType,
      'structureId': '', // à remplir si tu l’as
      'memberCount': memberCount,
      'priceAmount': priceAmount,
      'priceDisplay': priceDisplay,
      'currency': 'EUR',
      'billingPeriod': 'monthly',
    });
  }

  /// Affiche le dialog d'erreur
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Erreur'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Retourne le titre selon le type de structure
  String _getTitle() {
    if (widget.structureType == 'assistante_maternelle') {
      return 'Abonnement Assistant Maternel';
    } else {
      return 'Abonnement MAM $_selectedMamMembers Membres';
    }
  }

  /// Retourne le prix selon le type
  String _getPrice() {
    if (widget.structureType == 'assistante_maternelle') {
      return '8,99€';
    } else {
      switch (_selectedMamMembers) {
        case 2:
          return '19,99€';
        case 3:
          return '24,99€';
        case 4:
          return '29,99€';
        default:
          return '19,99€';
      }
    }
  }

  /// Retourne la description des fonctionnalités
  List<String> _getFeatures() {
    return [
      '📱 Transmissions en temps réel pour gagner du temps',
      '💬 Chat instantané avec les parents',
      '📸 Partage sécurisé des photos des enfants',
      '🔔 Notifications push pour ne rien manquer',
      '📊 Tableau de bord clair et complet',
      '👥 Collaboration simplifiée en équipe',
      '📋 Gestion administrative allégée',
      '☁️ Sauvegarde automatique et sécurisée',
    ];
  }

  /// Retourne le prix pour un nombre de membres donné
  String _getPriceForMembers(int members) {
    switch (members) {
      case 2:
        return '19,99€';
      case 3:
        return '24,99€';
      case 4:
        return '29,99€';
      default:
        return '19,99€';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un Abonnement'),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec badge essai gratuit
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryBlue, Color(0xFF2B7BD9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Badge essai gratuit
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🎁 7 JOURS GRATUITS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Titre et prix
                        Text(
                          _getTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _getPrice(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              '/mois',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Puis résiliation possible à tout moment',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sélecteur de nombre de membres pour MAM
                  if (widget.structureType != 'assistante_maternelle') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre de membres :',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (int members in [2, 3, 4])
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: members < 4 ? 8 : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedMamMembers = members;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedMamMembers == members
                                              ? Colors.blue[600]
                                              : Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color:
                                                _selectedMamMembers == members
                                                    ? Colors.blue[600]!
                                                    : Colors.grey[300]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '$members',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedMamMembers ==
                                                        members
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'membres',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _selectedMamMembers ==
                                                        members
                                                    ? Colors.white
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getPriceForMembers(members),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _selectedMamMembers ==
                                                        members
                                                    ? Colors.white
                                                    : Colors.blue[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Statut actuel
                  if (_activeSubscription != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[200]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[600]),
                              const SizedBox(width: 8),
                              const Text(
                                'Abonnement Actif',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (_activeSubscription!.isTrialPeriod) ...[
                            const SizedBox(height: 8),
                            Text(
                              '🎁 Période d\'essai gratuit',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Erreur
                  if (_errorMessage.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[200]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Fonctionnalités incluses
                  const Text(
                    'Fonctionnalités incluses :',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._getFeatures().map((feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check,
                                color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: 32),

                  // Informations légales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations importantes :',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• L\'abonnement se renouvelle automatiquement\n'
                          '• Résiliation possible à tout moment dans les paramètres ${Platform.isIOS ? 'iOS' : 'Android'}\n'
                          '• Prix affiché TTC pour la France',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Boutons d'action
                  if (_activeSubscription == null) ...[
                    // Bouton d'achat
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isPurchasing ? null : _purchaseSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isPurchasing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Traitement...'),
                                ],
                              )
                            : const Text(
                                'Commencer l\'essai gratuit de 7 jours',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bouton de restauration
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _isLoading ? null : _restorePurchases,
                      child: Text(
                        'Restaurer mes achats',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    // Le service sera nettoyé automatiquement
    super.dispose();
  }
}
