import 'package:flutter/material.dart';
import '../services/unified_subscription_service.dart';

class SubscriptionTestScreen extends StatefulWidget {
  @override
  _SubscriptionTestScreenState createState() => _SubscriptionTestScreenState();
}

class _SubscriptionTestScreenState extends State<SubscriptionTestScreen> {
  final UnifiedSubscriptionService _service =
      UnifiedSubscriptionService.instance;
  String _status = 'Prêt pour les tests Sandbox';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    setState(() => _isLoading = true);

    try {
      await _service.initialize();

      // Écouter les succès
      _service.subscriptionUpdates.listen((sub) {
        setState(() {
          _status =
              '✅ SUCCÈS: ${sub.productId}\nStatut: ${sub.status}\nPrix: ${sub.localizedPrice}';
        });

        // Afficher une alerte de succès
        _showDialog(
            'Achat réussi !',
            'Produit: ${sub.productId}\nPrix: ${sub.localizedPrice}',
            Colors.green);
      });

      // Écouter les erreurs
      _service.errors.listen((error) {
        setState(() {
          _status = '❌ ERREUR: $error';
        });
        _showDialog('Erreur', error, Colors.red);
      });

      setState(() => _status = '📱 Service initialisé - Sandbox connecté');
    } catch (e) {
      setState(() => _status = '💥 Erreur initialisation: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPurchase(
      SubscriptionPlan plan, String name, String price) async {
    setState(() {
      _isLoading = true;
      _status = '🛒 Test achat $name ($price)...';
    });

    try {
      print('🧪 SANDBOX: Tentative achat $name');
      final success = await _service.purchaseSubscription(plan);

      if (!success) {
        setState(() => _status = '❌ Échec initiation achat $name');
      } else {
        setState(
            () => _status = '⏳ Achat $name initié, attente confirmation...');
      }
    } catch (e) {
      setState(() => _status = '💥 Erreur achat $name: $e');
      _showDialog('Erreur', 'Erreur lors de l\'achat $name: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDialog(String title, String content, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error,
              color: color,
            ),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🧪 Test Sandbox'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Statut
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Text(
                _status,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 24),

            if (_isLoading)
              Column(
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text('Traitement en cours...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              )
            else ...[
              Text(
                '🧪 Mode Sandbox Actif',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tous les achats sont GRATUITS en sandbox',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // Boutons de test
              _buildTestButton(
                '👶 Assistant Maternel',
                '3,99€/mois',
                () => _testPurchase(SubscriptionPlan.assistantMaternel,
                    'Assistant Maternel', '3,99€'),
                Colors.blue,
              ),
              SizedBox(height: 12),
              _buildTestButton(
                '👥 MAM 2 membres',
                '9,99€/mois',
                () => _testPurchase(SubscriptionPlan.mam2Members,
                    'MAM 2', '9,99€'),
                Colors.green,
              ),
              SizedBox(height: 12),
              _buildTestButton(
                '👨‍👩‍👧 MAM 3 membres',
                '9,99€/mois',
                () => _testPurchase(SubscriptionPlan.mam3Members,
                    'MAM 3', '9,99€'),
                Colors.green,
              ),
              SizedBox(height: 12),
              _buildTestButton(
                '👨‍👩‍👧‍👦 MAM 4+ (illimité)',
                '14,99€/mois',
                () => _testPurchase(SubscriptionPlan.mam4PlusMembers,
                    'MAM 4+', '14,99€'),
                Colors.orange,
              ),

              SizedBox(height: 24),

              // Bouton restauration
              _buildTestButton(
                '🔄 Restaurer les achats',
                'Test de restauration',
                () async {
                  setState(() {
                    _isLoading = true;
                    _status = '🔄 Restauration des achats...';
                  });
                  try {
                    await _service.restorePurchases();
                    setState(() => _status = '✅ Restauration terminée');
                  } catch (e) {
                    setState(() => _status = '❌ Erreur restauration: $e');
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                Colors.purple,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
      String title, String subtitle, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
