import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firebase_trial_service.dart';
import '../theme/app_colors.dart';
import '../utils/structure_context.dart';

class AdminSubscriptionDashboardScreen extends StatefulWidget {
  const AdminSubscriptionDashboardScreen({super.key});

  @override
  State<AdminSubscriptionDashboardScreen> createState() =>
      _AdminSubscriptionDashboardScreenState();
}

const Set<String> _subscriptionAdminEmails = {
  'cbeylet06@gmail.com',
  'chrisgugu1101@gmail.com',
};

const Set<String> _inactiveSubscriptionStatuses = {
  'canceled',
  'cancelled',
  'expired',
  'revoked',
  'terminated',
  'ended',
  'inactive',
  'on_hold',
  'paused',
  'grace_period_expired',
};

const Set<String> _activeSubscriptionStatuses = {
  'active',
  'approved',
  'renewed',
  'renewing',
  'purchased',
  'succeeded',
  'grace',
  'grace_period',
  'in_grace_period',
  'recovered',
  'restarted',
};

class _AdminSubscriptionDashboardScreenState
    extends State<AdminSubscriptionDashboardScreen> {
  static const double _priceAssmat = 3.99;
  static const double _priceMamSmall = 9.99;
  static const double _priceMamLarge = 14.99;
  static const double _platformFeeRate = 0.15;
  bool _isAuthorizing = true;
  bool _isAuthorized = false;
  bool _isLoadingStats = true;
  String? _authorizationError;
  String? _statsError;
  bool _isExporting = false;
  bool _isExportingRecentExpirations = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _structuresSub;
  List<_StructureSubscriptionInfo> _entries = const [];
  _SubscriptionStats _stats = _SubscriptionStats.empty();

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  @override
  void dispose() {
    _structuresSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthorization() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isAuthorizing = false;
        _authorizationError = 'Utilisateur non authentifié.';
      });
      return;
    }

    final String email = currentUser.email?.toLowerCase().trim() ?? '';
    if (_subscriptionAdminEmails.contains(email)) {
      setState(() {
        _isAuthorized = true;
        _isAuthorizing = false;
      });
      _listenToStructures();
      return;
    }

    try {
      final StructureContext context = await StructureResolver().resolve();
      const String adminStructureId = 'e5udQot4UtYxsrOoqaHZ2n4VEkk1';
      final bool allowed = context.structureId == adminStructureId;

      setState(() {
        _isAuthorized = allowed;
        _isAuthorizing = false;
        if (!allowed) {
          _authorizationError = 'Accès réservé.';
        }
      });

      if (allowed) {
        _listenToStructures();
      }
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isAuthorizing = false;
        _authorizationError = 'Accès réservé.';
      });
    }
  }

  void _listenToStructures() {
    _structuresSub?.cancel();
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    _structuresSub = FirebaseFirestore.instance
        .collection('structures')
        .snapshots()
        .listen(
      (snapshot) {
        final List<_StructureSubscriptionInfo> entries = snapshot.docs
            .map((doc) => _StructureSubscriptionInfo.fromSnapshot(doc))
            .toList();

        entries.sort(
          (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        );

        if (!mounted) return;
        setState(() {
          _entries = entries;
          _stats = _SubscriptionStats.fromEntries(entries);
          _isLoadingStats = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _statsError = 'Impossible de charger les données ($error).';
          _isLoadingStats = false;
        });
      },
    );
  }

  Future<void> _forceRefresh() async {
    await FirebaseFirestore.instance.collection('structures').limit(1).get();
  }

  Future<void> _handleExportEndingTrials(BuildContext originContext) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await _exportTrialsEndingSoon(originContext);
    } catch (e) {
      _showSnackBar('Export impossible : $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleExportRecentExpiredTrials(
      BuildContext originContext) async {
    if (_isExportingRecentExpirations) return;
    setState(() => _isExportingRecentExpirations = true);
    try {
      await _exportTrialsExpiredRecently(originContext);
    } catch (e) {
      _showSnackBar('Export impossible : $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExportingRecentExpirations = false);
      }
    }
  }

  Future<void> _exportTrialsEndingSoon(BuildContext originContext) async {
    final List<_StructureSubscriptionInfo> expiringEntries = _entries.where(
      (entry) {
        if (!entry.hasActiveTrial) return false;
        final int daysRemaining = entry.trialStatus.daysRemaining;
        final String email = entry.ownerEmail?.trim() ?? '';
        return email.isNotEmpty && daysRemaining >= 1 && daysRemaining <= 2;
      },
    ).toList();

    if (expiringEntries.isEmpty) {
      _showSnackBar('Aucun essai à relancer dans les 2 prochains jours.');
      return;
    }

    final String content = expiringEntries
        .map((entry) => entry.ownerEmail!.trim())
        .join('\n');

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath =
        '${tempDir.path}/emails_essais_expirant_${DateTime.now().millisecondsSinceEpoch}.txt';
    final File file = File(filePath);
    await file.writeAsString(content);

    final RenderBox? renderBox =
        originContext.findRenderObject() as RenderBox?;
    final Rect? origin = renderBox != null
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Essais à relancer (J-2 / J-1).',
      subject: 'Essais Poppin\'s',
      sharePositionOrigin: origin,
    );
    _showSnackBar(
        '${expiringEntries.length} adresse(s) exportée(s) avec succès.');
  }

  Future<void> _exportTrialsExpiredRecently(
      BuildContext originContext) async {
    final DateTime now = DateTime.now();
    final DateTime twoDaysAgo = now.subtract(const Duration(days: 2));

    final List<_StructureSubscriptionInfo> recentlyExpiredEntries = _entries
        .where((entry) {
          final String email = entry.ownerEmail?.trim() ?? '';
          if (email.isEmpty) return false;
          if (!entry.trialStatus.hasStarted || !entry.trialStatus.isExpired) {
            return false;
          }
          final DateTime? trialEnd = entry.trialEnd;
          if (trialEnd == null) return false;
          return !trialEnd.isBefore(twoDaysAgo) && !trialEnd.isAfter(now);
        })
        .toList();

    if (recentlyExpiredEntries.isEmpty) {
      _showSnackBar('Aucun essai expiré sur les 2 derniers jours.');
      return;
    }

    final String content = recentlyExpiredEntries
        .map((entry) => entry.ownerEmail!.trim())
        .join('\n');

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath =
        '${tempDir.path}/emails_essais_expire_recent_${DateTime.now().millisecondsSinceEpoch}.txt';
    final File file = File(filePath);
    await file.writeAsString(content);

    final RenderBox? renderBox =
        originContext.findRenderObject() as RenderBox?;
    final Rect? origin = renderBox != null
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Essais expirés à relancer (dernières 48h).',
      subject: 'Essais expirés Poppin\'s',
      sharePositionOrigin: origin,
    );
    _showSnackBar(
        '${recentlyExpiredEntries.length} adresse(s) exportée(s) avec succès.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorizing) {
      return const Scaffold(
        appBar: _AdminAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: const _AdminAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _authorizationError ?? 'Accès réservé.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final List<_StructureSubscriptionInfo> activeTrials =
        _entries.where((entry) => entry.hasActiveTrial).toList()
          ..sort((a, b) => (a.trialEnd ?? DateTime(2100))
              .compareTo(b.trialEnd ?? DateTime(2100)));

    final List<_StructureSubscriptionInfo> confirmedSubscriptions =
        _entries.where((entry) => entry.hasConfirmedSubscription).toList();

    return Scaffold(
      appBar: const _AdminAppBar(),
      backgroundColor: kAppBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _forceRefresh,
        child: _isLoadingStats
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  if (_statsError != null) ...[
                    _buildErrorBanner(_statsError!),
                    const SizedBox(height: 12),
                  ],
                  _buildStatsGrid(context),
                  const SizedBox(height: 12),
                  _buildExportButton(),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: 'Essais actifs',
                    description:
                        'Structures actuellement dans les 7 jours d\'essai.',
                    color: Colors.orange.shade600,
                    entries: activeTrials,
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    title: 'Abonnements confirmés',
                    description:
                        'Structures avec abonnement payé (essai terminé).',
                    color: Colors.green.shade600,
                    entries: confirmedSubscriptions,
                  ),
                  const SizedBox(height: 16),
                  _buildHintCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final _CategoryCounts trialBreakdown = _stats.trialBreakdown;
    final _CategoryCounts subscriptionBreakdown =
        _stats.subscriptionBreakdown;
    final _PricingInfo trialPricing =
        _PricingInfo.fromCounts(trialBreakdown);
    final _PricingInfo subscriptionPricing =
        _PricingInfo.fromCounts(subscriptionBreakdown);
    final TextStyle valueStyle = Theme.of(context).textTheme.headlineMedium!
        .copyWith(fontWeight: FontWeight.bold);
    final TextStyle labelStyle = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: Colors.grey.shade700);

    Widget buildCard(
      String label,
      int value,
      Color color,
      List<_BreakdownItem> breakdown,
      _PricingInfo pricing,
    ) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: labelStyle.copyWith(color: color)),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: valueStyle.copyWith(color: color),
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...breakdown.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        item.value.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              label == 'Essais actifs'
                  ? 'Montant estimatif à venir'
                  : 'Montant brut des abonnements',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...pricing.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${line.label} ${_formatCurrency(line.unitPrice)} x ${line.count} = ${_formatCurrency(line.total)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total brut : ${_formatCurrency(pricing.gross)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Montant net (-15%) : ${_formatCurrency(pricing.net)}',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 600;
        final int crossAxisCount = isWide ? 2 : 1;
        final double childAspectRatio = isWide ? 0.45 : 1.05;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          children: [
            buildCard(
              'Essais actifs',
              trialBreakdown.total,
              Colors.orange.shade600,
              [
                _BreakdownItem('Assmat', trialBreakdown.assmat),
                _BreakdownItem('MAM 2-3', trialBreakdown.mamSmall),
                _BreakdownItem('MAM 4+', trialBreakdown.mamLarge),
              ],
              trialPricing,
            ),
            buildCard(
              'Abonnements',
              subscriptionBreakdown.total,
              Colors.green.shade600,
              [
                _BreakdownItem('Assmat', subscriptionBreakdown.assmat),
                _BreakdownItem('MAM 2-3', subscriptionBreakdown.mamSmall),
                _BreakdownItem('MAM 4+', subscriptionBreakdown.mamLarge),
              ],
              subscriptionPricing,
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportButton() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(builder: (buttonContext) {
            return ElevatedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _handleExportEndingTrials(buttonContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              icon: Icon(_isExporting ? Icons.hourglass_top : Icons.download),
              label: Text(
                _isExporting
                    ? 'Export en cours...'
                    : 'Exporter les emails (J-2 / J-1)',
              ),
            );
          }),
          const SizedBox(height: 10),
          Builder(builder: (buttonContext) {
            return ElevatedButton.icon(
              onPressed: _isExportingRecentExpirations
                  ? null
                  : () => _handleExportRecentExpiredTrials(buttonContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              icon: Icon(_isExportingRecentExpirations
                  ? Icons.hourglass_top
                  : Icons.history),
              label: Text(
                _isExportingRecentExpirations
                    ? 'Export en cours...'
                    : 'Emails essais expirés (48h)',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required Color color,
    required List<_StructureSubscriptionInfo> entries,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Text(
                    entries.length.toString(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Text(
                'Aucune structure.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Column(
                children: entries
                    .take(25)
                    .map((entry) => _SubscriptionTile(
                          info: entry,
                          color: color,
                        ))
                    .toList(),
              ),
            if (entries.length > 25) ...[
              const SizedBox(height: 12),
              Text(
                '+${entries.length - 25} supplémentaires…',
                style: TextStyle(
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHintCard() {
    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Nettoyage automatique',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les documents "subscriptions" ne peuvent pas être supprimés côté app (règles Firestore). '
              'Cette page filtre simplement les essais expirés pour rendre les vraies données lisibles. '
              'Si besoin d\'une purge, il faudra passer par une fonction serveur ou ajuster les règles.',
              style: TextStyle(
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.redAccent : Colors.blueGrey.shade700,
      ),
    );
  }

  String _formatCurrency(double value) {
    final NumberFormat format =
        NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    return format.format(value);
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({
    required this.info,
    required this.color,
  });

  final _StructureSubscriptionInfo info;
  final Color color;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date inconnue';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Text(
          info.structureInitials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        info.structureName,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.ownerEmail ?? 'Email inconnu'),
          Text(
            info.statusLabel,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          if (info.trialEnd != null && info.hasActiveTrial)
            Text(
              'Fin essai : ${_formatDate(info.trialEnd)} (${info.trialStatus.daysRemaining} jours restants)',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (info.updatedAt != null)
            Text(
              'MàJ: ${_formatDate(info.updatedAt)}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            info.structureTypeLabel,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          if (info.memberCount != null)
            Text(
              '${info.memberCount} membre(s)',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _StructureSubscriptionInfo {
  _StructureSubscriptionInfo({
    required this.structureId,
    required this.structureName,
    required this.structureType,
    required this.ownerEmail,
    required this.subscriptionStatus,
    required this.subscriptionActive,
    required this.trialStatus,
    required this.updatedAt,
    required this.memberCount,
  });

  final String structureId;
  final String structureName;
  final String structureType;
  final String? ownerEmail;
  final String subscriptionStatus;
  final bool subscriptionActive;
  final TrialStatus trialStatus;
  final DateTime? updatedAt;
  final int? memberCount;

  bool get hasActiveTrial =>
      trialStatus.isActive && !hasConfirmedSubscription; // avoid counting converted subscriptions as trials

  bool get hasExpiredTrial =>
      trialStatus.hasStarted && trialStatus.isExpired && !hasConfirmedSubscription;

  bool get hasConfirmedSubscription =>
      subscriptionActive &&
      !_statusIndicatesTrial(subscriptionStatus) &&
      !_statusIndicatesInactive(subscriptionStatus);

  DateTime? get trialEnd => trialStatus.endAt;

  String get structureInitials {
    final parts = structureName.trim().split(RegExp(r'\\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get statusLabel {
    if (hasActiveTrial) {
      return 'Essai en cours';
    }
    if (hasConfirmedSubscription) {
      return 'Abonnement actif';
    }
    if (hasExpiredTrial) {
      return 'Essai expiré';
    }
    if (trialStatus.hasStarted) {
      return 'Essai terminé';
    }
    if (_statusIndicatesTrial(subscriptionStatus)) {
      return 'Essai non démarré';
    }
    if (_statusIndicatesInactive(subscriptionStatus)) {
      return 'Abonnement inactif';
    }
    return subscriptionStatus.isEmpty ? 'Statut inconnu' : subscriptionStatus;
  }

  String get structureTypeLabel {
    final normalized = structureType.toLowerCase();
    if (normalized.contains('mam')) return 'MAM';
    if (normalized.contains('parent')) return 'Parent employeur';
    return 'Assmat';
  }

  bool get isMamStructure =>
      structureType.toLowerCase().contains('mam');

  int get effectiveMemberCount {
    final int? count = memberCount;
    if (count == null || count <= 0) {
      return isMamStructure ? 2 : 1;
    }
    return count;
  }

  static _StructureSubscriptionInfo fromSnapshot(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final TrialStatus trial = TrialStatus.fromStructureData(data);
    final dynamic ownerField = data['ownerEmail'] ?? data['email'];
    final String? ownerEmailValue =
        ownerField == null ? null : ownerField.toString().trim();
    String resolvedName =
        (data['structureName'] ?? data['ownerFirstName'] ?? 'Ma structure')
            .toString()
            .trim();
    if (resolvedName.isEmpty) {
      resolvedName = 'Structure ${doc.id}';
    }
    return _StructureSubscriptionInfo(
      structureId: doc.id,
      structureName: resolvedName,
      structureType: (data['structureType'] ?? 'assistante_maternelle')
          .toString(),
      ownerEmail:
          ownerEmailValue?.isEmpty ?? true ? null : ownerEmailValue,
      subscriptionStatus: (data['subscriptionStatus'] ?? data['trialStatus'] ?? '')
          .toString()
          .toLowerCase(),
      subscriptionActive: data['subscriptionActive'] == true,
      trialStatus: trial,
      updatedAt: _tryParseDate(
        data['subscriptionUpdatedAt'] ?? data['updatedAt'],
      ),
      memberCount: data['memberCount'] is int
          ? data['memberCount'] as int
          : (data['maxMemberCount'] is int ? data['maxMemberCount'] as int : null),
    );
  }

  static bool _statusIndicatesTrial(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('trial') || normalized == 'essai';
  }

  static bool _statusIndicatesInactive(String status) {
    final normalized = status.toLowerCase();
    if (normalized.isEmpty) return false;
    return _inactiveSubscriptionStatuses.contains(normalized);
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class _BreakdownItem {
  const _BreakdownItem(this.label, this.value);

  final String label;
  final int value;
}

class _CategoryCounts {
  const _CategoryCounts({
    required this.assmat,
    required this.mamSmall,
    required this.mamLarge,
  });

  final int assmat;
  final int mamSmall;
  final int mamLarge;

  int get total => assmat + mamSmall + mamLarge;

  static const empty =
      _CategoryCounts(assmat: 0, mamSmall: 0, mamLarge: 0);
}

class _SubscriptionStats {
  const _SubscriptionStats({
    required this.trialBreakdown,
    required this.subscriptionBreakdown,
  });

  final _CategoryCounts trialBreakdown;
  final _CategoryCounts subscriptionBreakdown;

  static _SubscriptionStats empty() => const _SubscriptionStats(
        trialBreakdown: _CategoryCounts.empty,
        subscriptionBreakdown: _CategoryCounts.empty,
      );

  static _SubscriptionStats fromEntries(
      List<_StructureSubscriptionInfo> entries) {
    int trialAssmat = 0;
    int trialMamSmall = 0;
    int trialMamLarge = 0;
    int subAssmat = 0;
    int subMamSmall = 0;
    int subMamLarge = 0;

    for (final entry in entries) {
      if (entry.hasActiveTrial) {
        final _Category category = _categoryFromEntry(entry);
        switch (category) {
          case _Category.assmat:
            trialAssmat++;
            break;
          case _Category.mamSmall:
            trialMamSmall++;
            break;
          case _Category.mamLarge:
            trialMamLarge++;
            break;
        }
      } else if (entry.hasConfirmedSubscription) {
        final _Category category = _categoryFromEntry(entry);
        switch (category) {
          case _Category.assmat:
            subAssmat++;
            break;
          case _Category.mamSmall:
            subMamSmall++;
            break;
          case _Category.mamLarge:
            subMamLarge++;
            break;
        }
      }
    }

    return _SubscriptionStats(
      trialBreakdown: _CategoryCounts(
        assmat: trialAssmat,
        mamSmall: trialMamSmall,
        mamLarge: trialMamLarge,
      ),
      subscriptionBreakdown: _CategoryCounts(
        assmat: subAssmat,
        mamSmall: subMamSmall,
        mamLarge: subMamLarge,
      ),
    );
  }
}

enum _Category { assmat, mamSmall, mamLarge }

_Category _categoryFromEntry(_StructureSubscriptionInfo entry) {
  if (!entry.isMamStructure) {
    return _Category.assmat;
  }
  final int memberCount = entry.effectiveMemberCount;
  if (memberCount >= 4) {
    return _Category.mamLarge;
  }
  return _Category.mamSmall;
}

class _PricingLine {
  const _PricingLine({
    required this.label,
    required this.count,
    required this.unitPrice,
  });

  final String label;
  final int count;
  final double unitPrice;

  double get total => count * unitPrice;
}

class _PricingInfo {
  const _PricingInfo(this.lines);

  final List<_PricingLine> lines;

  double get gross =>
      lines.fold<double>(0, (sum, line) => sum + line.total);

  double get net => gross * (1 - _AdminSubscriptionDashboardScreenState._platformFeeRate);

  static _PricingInfo fromCounts(_CategoryCounts counts) {
    return _PricingInfo([
      _PricingLine(
        label: 'Assmat',
        count: counts.assmat,
        unitPrice: _AdminSubscriptionDashboardScreenState._priceAssmat,
      ),
      _PricingLine(
        label: 'MAM 2-3',
        count: counts.mamSmall,
        unitPrice: _AdminSubscriptionDashboardScreenState._priceMamSmall,
      ),
      _PricingLine(
        label: 'MAM 4+',
        count: counts.mamLarge,
        unitPrice: _AdminSubscriptionDashboardScreenState._priceMamLarge,
      ),
    ]);
  }
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AdminAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Abonnements & essais'),
      backgroundColor: const Color(0xFF3D9DF2),
      foregroundColor: Colors.white,
    );
  }
}
