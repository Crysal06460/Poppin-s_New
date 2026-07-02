import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/remplacement_session_service.dart';

/// Bandeau global affiché pendant une session "Remplacement" active.
/// Calqué sur le pattern de `DemoModeBannerOverlay` (Stack/Positioned/
/// SafeArea par-dessus `widget.child`).
///
/// Deux états, à partir du marqueur local (côté remplaçante) OU d'une
/// requête live sur `structures/{uid}/remplacements` (côté propriétaire) :
/// - Remplaçante : "Vous intervenez en tant que remplaçante de {ownerName}
///   jusqu'au {endDate}" + bouton "Terminer maintenant".
/// - Propriétaire reconnectée pendant la période : "{replacementName}
///   intervient en tant que remplaçante jusqu'au {endDate}" + "Révoquer".
class RemplacementBannerOverlay extends StatefulWidget {
  const RemplacementBannerOverlay({super.key, required this.child});

  final Widget? child;

  @override
  State<RemplacementBannerOverlay> createState() =>
      _RemplacementBannerOverlayState();
}

class _RemplacementBannerOverlayState
    extends State<RemplacementBannerOverlay> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownerSub;
  Map<String, dynamic>? _ownerSideActiveDoc;
  String? _ownerSideDocId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    RemplacementSessionService.instance.marker.addListener(_onMarkerChanged);
    // Vérification best-effort au premier build : rafraîchit le marqueur
    // depuis SharedPreferences (utile après un redémarrage à froid, avant
    // même qu'AuthCheckScreen n'ait fini son propre contrôle).
    RemplacementSessionService.instance.checkStillActive();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _resubscribeOwnerSide();
    });
    _resubscribeOwnerSide();
  }

  void _onMarkerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _resubscribeOwnerSide() {
    _ownerSub?.cancel();
    _ownerSub = null;

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _ownerSideActiveDoc = null;
          _ownerSideDocId = null;
        });
      }
      return;
    }

    // Ne concerne que les vraies propriétaires de structure (doc ID ==
    // uid). Pour un membre MAM/parent, la requête renvoie simplement une
    // liste vide (le doc `structures/{uid}` n'existe pas) — pas d'erreur.
    _ownerSub = FirebaseFirestore.instance
        .collection('structures')
        .doc(uid)
        .collection('remplacements')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snap) {
      if (!mounted) return;
      setState(() {
        if (snap.docs.isEmpty) {
          _ownerSideActiveDoc = null;
          _ownerSideDocId = null;
        } else {
          _ownerSideActiveDoc = snap.docs.first.data();
          _ownerSideDocId = snap.docs.first.id;
        }
      });
    }, onError: (_) {
      // Non-propriétaire ou hors ligne : ignorer silencieusement.
    });
  }

  @override
  void dispose() {
    RemplacementSessionService.instance.marker
        .removeListener(_onMarkerChanged);
    _authSub?.cancel();
    _ownerSub?.cancel();
    super.dispose();
  }

  String _formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final DateTime? date = DateTime.tryParse(iso);
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String? _ownerDocEndDateIso() {
    final dynamic ts = _ownerSideActiveDoc?['endDate'];
    if (ts is Timestamp) return ts.toDate().toIso8601String();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String?>? replacementMarker =
        RemplacementSessionService.instance.marker.value;
    final bool isReplacementSide = replacementMarker != null &&
        (replacementMarker['structureId']?.isNotEmpty ?? false);
    final bool isOwnerSide = !isReplacementSide && _ownerSideActiveDoc != null;

    if (!isReplacementSide && !isOwnerSide) {
      return widget.child ?? const SizedBox.shrink();
    }

    const double bannerHeight = 96;

    final String title = isReplacementSide
        ? "Vous intervenez en tant que remplaçante de "
            "${replacementMarker['ownerName'] ?? ''} jusqu'au "
            "${_formatIsoDate(replacementMarker['endDate'])}"
        : "${(_ownerSideActiveDoc?['replacementFirstName'] ?? '')} "
            "${(_ownerSideActiveDoc?['replacementLastName'] ?? '')} "
            "intervient en tant que remplaçante jusqu'au "
            "${_formatIsoDate(_ownerDocEndDateIso())}";

    return Stack(
      children: [
        if (widget.child != null)
          Padding(
            padding: const EdgeInsets.only(top: bannerHeight + 16),
            child: widget.child!,
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2B705),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : (isReplacementSide ? _endNow : _revoke),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withOpacity(0.15),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(isReplacementSide
                            ? "Terminer maintenant"
                            : "Révoquer"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _endNow() async {
    setState(() => _busy = true);
    await RemplacementSessionService.instance.endSessionManually();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _revoke() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final String? docId = _ownerSideDocId;
    if (uid == null || docId == null) return;

    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('cancelRemplacement')
          .call({'structureId': uid, 'remplacementId': docId});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la révocation: $e")),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }
}
