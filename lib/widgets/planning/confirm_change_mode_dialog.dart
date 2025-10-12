import 'package:flutter/material.dart';

import '../../planning/planning_models.dart';

Future<bool> showConfirmChangeModeDialog(
  BuildContext context, {
  required PlanningType from,
  required PlanningType to,
}) async {
  final toLabel = _targetLabel(to);
  final removalPhrase = _removalPhrase(from);
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Changer le mode de planning ?'),
            content: Text(
              'Si vous passez à $toLabel, $removalPhrase. Voulez-vous continuer ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continuer'),
              ),
            ],
          );
        },
      ) ??
      false;
}

String _targetLabel(PlanningType type) {
  switch (type) {
    case PlanningType.fixed:
      return 'Horaires fixes';
    case PlanningType.altWeeks:
      return '1 sem/2';
    case PlanningType.monthly:
      return 'Planning mensuel';
  }
}

String _removalPhrase(PlanningType type) {
  switch (type) {
    case PlanningType.fixed:
      return 'les horaires fixes seront effacés';
    case PlanningType.altWeeks:
      return 'le planning 1 sem/2 sera effacé';
    case PlanningType.monthly:
      return 'le planning mensuel sera effacé';
  }
}
