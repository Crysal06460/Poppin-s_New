import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Chemin de la route actuellement affichée, mis à jour via [attachAideRouteTracking].
/// Permet au bouton d'aide flottant global de savoir quelle FAQ afficher
/// sans que chaque écran ait besoin de s'enregistrer manuellement.
final ValueNotifier<String> currentRoutePath = ValueNotifier<String>('/');

/// À appeler une seule fois après la création du [GoRouter] (dans main.dart).
/// La plupart des [GoRoute] de l'app ne déclarent pas de `name`, donc on lit
/// directement l'URI courante via le routeInformationProvider plutôt que de
/// dépendre d'un NavigatorObserver.
void attachAideRouteTracking(GoRouter router) {
  void update() {
    currentRoutePath.value = router.routeInformationProvider.value.uri.path;
  }

  update();
  router.routeInformationProvider.addListener(update);
}
