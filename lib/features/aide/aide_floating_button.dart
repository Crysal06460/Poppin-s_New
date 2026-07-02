import 'package:flutter/material.dart';
import '../../routes.dart';
import 'aide_faq_data.dart';
import 'aide_route_observer.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);

/// Seuls les 12 écrans de fonctionnalités accessibles depuis la grille du
/// Home doivent afficher le bouton d'aide — nulle part ailleurs (dashboard,
/// administration, paramètres, écrans publics, etc.). Liste calquée sur la
/// grille `features` de home_screen.dart.
const Set<String> _visibleOnPaths = {
  '/horaires',
  '/repas',
  '/activites',
  '/sieste',
  '/sante',
  '/change',
  '/photos',
  '/agenda',
  '/stock',
  '/recap-enfant',
  '/actualites',
  '/transmissions',
};

/// Bouton d'aide flottant global (injecté une seule fois au niveau du
/// `builder` de MaterialApp dans main.dart), mais visible uniquement sur les
/// 12 écrans de fonctionnalités du Home ([_visibleOnPaths]).
/// Ouvre une FAQ statique adaptée à l'écran courant — aucun appel IA, donc
/// aucun coût et aucun risque de réponse erronée.
class AideFloatingButton extends StatelessWidget {
  const AideFloatingButton({super.key});

  void _openFaq() {
    // Le contexte du `builder` global de MaterialApp.router est au-dessus du
    // Navigator (pas dedans) : il faut passer par rootNavigatorKey pour
    // obtenir un contexte qui a effectivement un Navigator ancêtre.
    final BuildContext? navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    final List<FaqItem> items =
        aideFaqParEcran[currentRoutePath.value] ?? aideFaqParDefaut;

    showModalBottomSheet(
      context: navigatorContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AideFaqSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentRoutePath,
      builder: (context, path, _) {
        if (!_visibleOnPaths.contains(path)) {
          return const SizedBox.shrink();
        }
        return Positioned(
          right: 16,
          bottom: 100,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openFaq,
              customBorder: const CircleBorder(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primaryBlue,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AideFaqSheet extends StatelessWidget {
  final List<FaqItem> items;

  const _AideFaqSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline, color: _primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Besoin d\'aide ?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ExpansionTile(
                    title: Text(
                      item.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    expandedAlignment: Alignment.topLeft,
                    children: [
                      Text(
                        item.reponse,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.75),
                          height: 1.4,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
