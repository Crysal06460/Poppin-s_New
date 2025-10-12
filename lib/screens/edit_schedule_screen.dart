import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../planning/planning_models.dart';
import '../planning/planning_repository.dart';
import '../widgets/planning/planning_editor.dart';

class EditScheduleScreen extends StatefulWidget {
  const EditScheduleScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.currentSchedule,
  });

  final String childId;
  final String childName;
  final Map<String, dynamic>? currentSchedule; // Conservé pour compatibilité

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final PlanningRepository _repository = PlanningRepository();
  late final PlanningEditorController _editorController =
      PlanningEditorController(repository: _repository);

  PlanningData? _planning;
  String? _structureId;
  String? _userId;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _validationError;
  Key _editorKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Utilisateur non authentifié.';
          _loading = false;
        });
        return;
      }

      final structureId = await _resolveStructureId(user);
      final planning = await _editorController.init(
        structureId: structureId,
        childId: widget.childId,
        userId: user.uid,
      );

      if (!mounted) return;
      setState(() {
        _planning = planning;
        _structureId = structureId;
        _userId = user.uid;
        _loading = false;
        _editorKey = UniqueKey();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement : $e';
        _loading = false;
      });
    }
  }

  Future<String> _resolveStructureId(User user) async {
    var structureId = user.uid;
    final email = user.email?.toLowerCase();
    if (email != null && email.isNotEmpty) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(email).get();
      final data = doc.data();
      if (data != null &&
          data['role'] == 'mamMember' &&
          data['structureId'] is String &&
          (data['structureId'] as String).isNotEmpty) {
        structureId = data['structureId'];
      }
    }
    return structureId;
  }

  void _handlePlanningChanged(PlanningData planning) {
    setState(() {
      _planning = planning;
      _validationError = null;
    });
  }

  void _handleValidationError(String message) {
    setState(() => _validationError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    final planning = _planning;
    final structureId = _structureId;
    final userId = _userId;
    if (planning == null || structureId == null || userId == null) {
      return;
    }

    if (!_hasActiveSlots(planning)) {
      _handleValidationError(
        'Veuillez ajouter au moins un créneau dans le mode sélectionné.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _validationError = null;
    });

    try {
      final updated = planning.copyWith(
        timezone:
            planning.timezone.isNotEmpty ? planning.timezone : 'Europe/Paris',
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _editorController.save(
        structureId: structureId,
        childId: widget.childId,
        planning: updated,
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horaires enregistrés')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
      );
    }
  }

  bool _hasActiveSlots(PlanningData planning) {
    switch (planning.type) {
      case PlanningType.fixed:
        final schema = planning.fixed;
        if (schema == null) return false;
        final hasDays = schema.days.values.any((slots) => slots.isNotEmpty);
        final hasExceptions = schema.exceptions.any((e) => e.slots.isNotEmpty);
        return hasDays || hasExceptions;
      case PlanningType.altWeeks:
        final schema = planning.altWeeks;
        if (schema == null) return false;
        final weekA = schema.weekA.days.values.any((slots) => slots.isNotEmpty);
        final weekB = schema.weekB.days.values.any((slots) => slots.isNotEmpty);
        final exceptions = schema.exceptions.any((e) => e.slots.isNotEmpty);
        return weekA || weekB || exceptions;
      case PlanningType.monthly:
        final schema = planning.monthly;
        if (schema == null) return false;
        final hasSpecificDays = schema.months.values.any(
          (month) => month.days.values.any((slots) => slots.isNotEmpty),
        );
        if (hasSpecificDays) return true;
        final fallback = schema.fallback;
        if (fallback == null) return false;
        return fallback.days.values.any((slots) => slots.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Horaires de ${widget.childName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: _initialise,
                )
              : _planning == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                if (_validationError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ValidationBanner(
                                      message: _validationError!,
                                    ),
                                  ),
                                PlanningEditor(
                                  key: _editorKey,
                                  initialPlanning: _planning!,
                                  onPlanningChanged: _handlePlanningChanged,
                                  onValidationError: _handleValidationError,
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text('Enregistrer'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
