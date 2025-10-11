import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/demo_mode_service.dart';

class DemoModeBannerOverlay extends StatefulWidget {
  const DemoModeBannerOverlay({super.key, required this.child});

  final Widget? child;

  @override
  State<DemoModeBannerOverlay> createState() => _DemoModeBannerOverlayState();
}

class _DemoModeBannerOverlayState extends State<DemoModeBannerOverlay> {
  late DemoModeState _state;
  StreamSubscription<DemoModeState>? _subscription;
  bool _expiryDialogShown = false;

  @override
  void initState() {
    super.initState();
    _state = DemoModeService.instance.state;
    _subscription = DemoModeService.instance.stream.listen((state) {
      setState(() {
        _state = state;
      });
      if (state.expired && !_expiryDialogShown) {
        _expiryDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showExpiredDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.isDemo) {
      return widget.child ?? const SizedBox.shrink();
    }

    const double bannerHeight = 96;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3D9DF2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _buildTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: TextButton(
                          onPressed: () {
                            context.go('/pricing', extra: {
                              'source': 'demo',
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.white),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Déverrouiller mon essai 7 jours",
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Données fictives — aucune action réelle n'est envoyée.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildTitle() {
    if (_state.expired) {
      return "Mode démo expiré — merci d'avoir testé Poppin's 💙";
    }
    final Duration? remaining = _state.remaining;
    if (remaining == null) {
      return "Mode Démo — données fictives";
    }
    final int hours = remaining.inHours;
    final int minutes = remaining.inMinutes.remainder(60);
    final String timeLabel =
        hours > 0 ? "$hours h ${minutes.toString().padLeft(2, '0')}" : "$minutes min";
    return "Mode Démo — $timeLabel restantes";
  }

  Future<void> _showExpiredDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Fin de la démo"),
          content: const Text(
            "Merci d'avoir testé Poppin's !\n"
            "Vous pouvez prolonger l'expérience avec 7 jours offerts.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/pricing', extra: {'source': 'demo_expired'});
              },
              child: const Text('Démarrer mon essai gratuit'),
            ),
          ],
        );
      },
    );
  }
}
