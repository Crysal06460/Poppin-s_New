// lib/widgets/subscription_summary_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/subscription_helper.dart';

class SubscriptionSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> subscriptionInfo;
  final VoidCallback? onCancelSubscription;

  const SubscriptionSummaryWidget({
    Key? key,
    required this.subscriptionInfo,
    this.onCancelSubscription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!subscriptionInfo['hasActiveSubscription']) {
      return _buildNoSubscriptionCard();
    }

    return _buildActiveSubscriptionCard(context);
  }

  Widget _buildNoSubscriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Aucun abonnement actif',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous pouvez supprimer votre compte immédiatement sans frais.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionCard(BuildContext context) {
    final bool isTrialPeriod = subscriptionInfo['isTrialPeriod'] ?? false;
    final int daysRemaining = subscriptionInfo['daysRemaining'] ?? 0;
    final String priceDisplay = subscriptionInfo['priceDisplay'] ?? 'N/A';
    final double refundAmount =
        SubscriptionHelper.calculateProRataRefund(subscriptionInfo);
    final DateTime? expirationDate = subscriptionInfo['expirationDate'];
    final String platform = subscriptionInfo['platform'] ?? 'unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTrialPeriod ? Colors.blue[50] : Colors.orange[50],
        border: Border.all(
          color: isTrialPeriod ? Colors.blue[200]! : Colors.orange[200]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Icon(
                isTrialPeriod ? Icons.star : Icons.warning,
                color: isTrialPeriod ? Colors.blue[600] : Colors.orange[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTrialPeriod
                      ? 'Période d\'essai active'
                      : 'Abonnement payant actif',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Informations sur l'abonnement
          _buildInfoRow('Type', _getSubscriptionTypeText()),
          _buildInfoRow('Prix', priceDisplay),
          _buildInfoRow('Plateforme', _getPlatformText(platform)),

          if (expirationDate != null)
            _buildInfoRow(
              'Expire le',
              DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(expirationDate),
            ),

          _buildInfoRow(
            'Temps restant',
            _getTimeRemainingText(daysRemaining),
          ),

          // Informations sur le remboursement
          if (!isTrialPeriod && refundAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.euro, color: Colors.green[700], size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Remboursement potentiel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vous pourriez obtenir un remboursement de ${refundAmount.toStringAsFixed(2)}€ auprès de ${platform == 'ios' ? 'Apple' : 'Google'}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Avertissement pour période d'essai
          if (isTrialPeriod) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous êtes en période d\'essai gratuit. Aucun remboursement n\'est nécessaire.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Bouton d'action si fourni
          if (onCancelSubscription != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancelSubscription,
                icon: Icon(
                  Icons.launch,
                  size: 16,
                  color: Colors.blue[600],
                ),
                label: Text(
                  'Ouvrir les paramètres ${platform == 'ios' ? 'iOS' : 'Android'}',
                  style: TextStyle(color: Colors.blue[600]),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue[600]!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubscriptionTypeText() {
    final String structureType = subscriptionInfo['structureType'] ?? 'unknown';
    final int memberCount = subscriptionInfo['memberCount'] ?? 1;

    if (structureType == 'assistante_maternelle') {
      return 'Assistant(e) Maternel(le)';
    } else if (structureType == 'MAM' || structureType.toLowerCase() == 'mam') {
      return 'MAM $memberCount membre${memberCount > 1 ? 's' : ''}';
    } else if (structureType.toLowerCase() == 'parent_employeur' ||
        structureType.toLowerCase() == 'parentemployeur') {
      return 'Parent employeur';
    } else {
      return 'Type inconnu';
    }
  }

  String _getPlatformText(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return 'iPhone/iPad (App Store)';
      case 'android':
        return 'Android (Google Play)';
      default:
        return 'Plateforme inconnue';
    }
  }

  String _getTimeRemainingText(int daysRemaining) {
    if (daysRemaining <= 0) {
      return 'Expiré';
    } else if (daysRemaining == 1) {
      return '1 jour restant';
    } else {
      return '$daysRemaining jours restants';
    }
  }
}

// Widget optionnel pour afficher les instructions de résiliation
class CancellationInstructionsWidget extends StatelessWidget {
  final String platform;
  final bool isExpanded;
  final VoidCallback onToggle;

  const CancellationInstructionsWidget({
    Key? key,
    required this.platform,
    required this.isExpanded,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Comment résilier mon abonnement ?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue[600],
                  ),
                ],
              ),
            ),
          ),

          // Contenu extensible
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                SubscriptionHelper.getCancellationInstructions(platform),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
