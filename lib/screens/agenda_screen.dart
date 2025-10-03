import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../widgets/common_app_bar.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../utils/structure_context.dart';
import '../services/notification_service.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({Key? key}) : super(key: key);

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  static const Color _primaryBlue = Color(0xFF3D9DF2);
  static const Color _primaryYellow = Color(0xFFF2B705);

  // Couleurs officielles de l'application
  static const Color _primaryRed = Color(0xFFD94350);
  static const Color _primaryCyan = Color(0xFF05C7F2);
  static const Color _lightBlueGrey = Color(0xFFDFE9F2);

  // Couleurs dérivées pour l'interface
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  final List<_AgendaEntry> _entries = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _isLoading = true;
  bool _isMamStructure = false;
  String? _structureId;
  String _structureName = 'Agenda';
  String? _userEmail;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadContext();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final structureContext = await StructureResolver().resolve();

      if (!mounted) return;

      setState(() {
        _structureId = structureContext.structureId;
        _userEmail = structureContext.currentUserEmail;
        _structureName = structureContext.structureName;
        _isMamStructure = structureContext.normalizedStructureType == 'mam';
      });

      _subscribeToAgenda();
    } catch (e) {
      print('Erreur lors du chargement du contexte agenda: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger l\'agenda')),
      );
    }
  }

  void _subscribeToAgenda() {
    final structureId = _structureId;
    if (structureId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _subscription?.cancel();
    setState(() {
      _isLoading = true;
    });

    final collection = FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('agendaEntries')
        .orderBy('dueDate');

    _subscription = collection.snapshots().listen((snapshot) {
      final email = (_userEmail ?? '').toLowerCase();
      final previousIds = _entries.map((entry) => entry.id).toSet();
      final entries = snapshot.docs
          .map((doc) => _AgendaEntry.fromDocument(doc.id, doc.data()))
          .where((entry) => entry.isVisibleFor(email))
          .toList();

      final Set<String> newIds = entries.map((entry) => entry.id).toSet();
      final Iterable<String> removedIds = previousIds.difference(newIds);

      for (final id in removedIds) {
        unawaited(NotificationService.cancelAgendaReminder(id));
      }

      for (final entry in entries) {
        unawaited(NotificationService.scheduleAgendaReminder(
          entryId: entry.id,
          scheduledAt: entry.dueDate,
          title: entry.title,
          body: entry.notes,
        ));
      }

      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(entries);
        _isLoading = false;
      });
    }, onError: (error) {
      print('Erreur de synchronisation agenda: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erreur lors de la récupération de l\'agenda')),
      );
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/exchanges');
    }
  }

  void _showAgendaForm({_AgendaEntry? entry}) {
    final titleController = TextEditingController(text: entry?.title ?? '');
    final notesController = TextEditingController(text: entry?.notes ?? '');
    final DateTime now = DateTime.now();
    final DateTime initialDueDate = entry?.dueDate ?? now.add(const Duration(hours: 1));
    DateTime selectedDate =
        DateTime(initialDueDate.year, initialDueDate.month, initialDueDate.day);
    TimeOfDay selectedTime =
        TimeOfDay(hour: initialDueDate.hour, minute: initialDueDate.minute);
    bool shareWithStructure =
        entry?.isShared ?? (_isMamStructure ? true : false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDate() async {
                final DateTime today = DateTime.now();
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(today.year - 5),
                  lastDate: DateTime(today.year + 5),
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) {
                  setModalState(() {
                    selectedDate = picked;
                  });
                }
              }

              Future<void> pickTime() async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        alwaysUse24HourFormat: true,
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked != null) {
                  setModalState(() {
                    selectedTime = picked;
                  });
                }
              }

              Future<void> submit() async {
                final String trimmedTitle = titleController.text.trim();
                if (trimmedTitle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ajoute un titre à ton rappel')),
                  );
                  return;
                }

                final DateTime combinedDueDate = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final bool success = await _saveAgendaEntry(
                  entryId: entry?.id,
                  title: trimmedTitle,
                  notes: notesController.text.trim(),
                  dueDate: combinedDueDate,
                  shareWithStructure: shareWithStructure,
                  originalCreator: entry?.createdBy,
                );

                if (success && mounted) {
                  Navigator.of(sheetContext).pop();
                }
              }

              Future<void> remove() async {
                Navigator.of(sheetContext).pop();
                _confirmDeletion(entry!);
              }

              final DateTime previewDateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              final String formattedDate =
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(previewDateTime);
              final String capitalizedDate =
                  formattedDate[0].toUpperCase() + formattedDate.substring(1);
              final String formattedTime =
                  DateFormat('HH:mm', 'fr_FR').format(previewDateTime);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry == null
                            ? 'Nouvelle entrée'
                            : 'Modifier l\'entrée',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Ex : Demander maillot pour sortie piscine',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      hintText: 'Ajouter un détail pour te souvenir',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(capitalizedDate),
                    subtitle: const Text('Touchez pour sélectionner une date'),
                    onTap: pickDate,
                    trailing: const Icon(Icons.edit_calendar_outlined),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text('À $formattedTime'),
                    subtitle:
                        const Text('Touchez pour sélectionner une heure'),
                    onTap: pickTime,
                    trailing: const Icon(Icons.schedule_outlined),
                  ),
                  if (_isMamStructure) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Partager avec toute la MAM'),
                      subtitle: const Text(
                        'En activant cette option, tous les membres verront ce rappel.',
                      ),
                      value: shareWithStructure,
                      onChanged: (value) {
                        setModalState(() {
                          shareWithStructure = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.save),
                    label: Text(entry == null
                        ? 'Enregistrer'
                        : 'Enregistrer les modifications'),
                  ),
                  if (entry != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: remove,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer cette entrée'),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _saveAgendaEntry({
    String? entryId,
    required String title,
    required String notes,
    required DateTime dueDate,
    required bool shareWithStructure,
    String? originalCreator,
  }) async {
    final structureId = _structureId;
    final email = _userEmail;
    if (structureId == null || email == null) {
      return false;
    }

    try {
      final collection = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('agendaEntries');

      final List<String> visibility = shareWithStructure ? ['all'] : [email];

      final Map<String, dynamic> payload = {
        'title': title,
        'dueDate': Timestamp.fromDate(dueDate),
        'visibleTo': visibility,
        'createdBy': originalCreator ?? email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (notes.isNotEmpty) {
        payload['notes'] = notes;
      } else if (entryId != null) {
        payload['notes'] = FieldValue.delete();
      }

      if (entryId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrée ajoutée à l\'agenda')),
          );
        }
      } else {
        await collection.doc(entryId).update(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrée mise à jour')),
          );
        }
      }
      return true;
    } catch (e) {
      print('Erreur sauvegarde agenda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'enregistrer l\'entrée')),
        );
      }
      return false;
    }
  }

  Future<void> _confirmDeletion(_AgendaEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce rappel ?'),
          content: Text(
            '"${entry.title}" sera supprimé de l\'agenda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAgendaEntry(entry);
    }
  }

  Future<void> _deleteAgendaEntry(_AgendaEntry entry) async {
    final structureId = _structureId;
    if (structureId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('agendaEntries')
          .doc(entry.id)
          .delete();

      await NotificationService.cancelAgendaReminder(entry.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrée supprimée')),
        );
      }
    } catch (e) {
      print('Erreur suppression agenda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de supprimer l\'entrée')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/Icone_Agenda.png',
              width: 120,
              height: 120,
              color: _primaryBlue.withOpacity(0.9),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ton agenda est encore vide',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoute un rappel pour ne rien oublier : ordonnance, dossier à récupérer, sortie à préparer…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaList() {
    return Container(
      color: _lightBlueGrey.withOpacity(0.2), // Fond avec couleur officielle
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return _buildAgendaCard(entry);
        },
      ),
    );
  }

  Widget _buildAgendaCard(_AgendaEntry entry) {
    final int diff = entry.daysFromToday;
    final bool isPast = diff < 0;
    final bool isToday = diff == 0;
    final bool isTomorrow = diff == 1;

    // Configuration des couleurs officielles selon l'urgence
    Color priorityColor;
    IconData priorityIcon;
    String deadlineLabel;

    if (isPast) {
      priorityColor = _primaryRed; // Rouge officiel
      priorityIcon = Icons.warning_amber_rounded;
      deadlineLabel = diff == -1 ? 'Hier' : 'Il y a ${diff.abs()} jours';
    } else if (isToday) {
      priorityColor = _primaryCyan; // Cyan officiel
      priorityIcon = Icons.today_rounded;
      deadlineLabel = 'Aujourd\'hui';
    } else if (isTomorrow) {
      priorityColor = _primaryYellow; // Jaune officiel
      priorityIcon = Icons.schedule_rounded;
      deadlineLabel = 'Demain';
    } else {
      priorityColor = _primaryBlue; // Bleu officiel
      priorityIcon = Icons.calendar_month_rounded;
      deadlineLabel = 'Dans $diff jours';
    }

    final String formattedDate =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(entry.dueDate);
    final String capitalizedDate =
        formattedDate[0].toUpperCase() + formattedDate.substring(1);
    final String? formattedTime = entry.hasSpecificTime
        ? DateFormat('HH:mm', 'fr_FR').format(entry.dueDate)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: _lightBlueGrey, width: 1), // Couleur officielle
        boxShadow: [
          BoxShadow(
            color:
                _primaryBlue.withOpacity(0.08), // Ombre avec couleur officielle
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showAgendaForm(entry: entry),
            child: Column(
              children: [
                // Header avec barre colorée (couleurs officielles)
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête avec priorité et partage
                      Row(
                        children: [
                          // Indicateur de priorité
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: priorityColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  priorityIcon,
                                  size: 14,
                                  color: priorityColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  deadlineLabel,
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Badge de partage avec couleurs officielles
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: entry.isShared
                                  ? _primaryCyan.withOpacity(0.1)
                                  : _lightBlueGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  entry.isShared
                                      ? Icons.groups_rounded
                                      : Icons.person_rounded,
                                  size: 12,
                                  color: entry.isShared
                                      ? _primaryCyan
                                      : _textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  entry.isShared ? 'MAM' : 'Perso',
                                  style: TextStyle(
                                    color: entry.isShared
                                        ? _primaryCyan
                                        : _textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Titre principal
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Date avec icône (couleur officielle)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _lightBlueGrey, // Couleur officielle
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: _primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formattedTime != null
                                  ? '$capitalizedDate à $formattedTime'
                                  : capitalizedDate,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Notes si présentes
                      if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _lightBlueGrey
                                .withOpacity(0.3), // Couleur officielle
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _lightBlueGrey,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            entry.notes!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Actions avec couleurs officielles
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showAgendaForm(entry: entry),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryBlue,
                                side: BorderSide(
                                    color: _primaryBlue.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text(
                                'Modifier',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => _confirmDeletion(entry),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryRed, // Rouge officiel
                              side: BorderSide(
                                  color: _primaryRed.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = MediaQuery.of(context).size.shortestSide >= 600;

    return SwipeNavigationWrapper(
      child: Scaffold(
        backgroundColor: _surfaceColor,
        body: Column(
          children: [
            CommonAppBar(
              title: 'Agenda',
              structureName: _structureName,
              iconPath: 'assets/images/Icone_Agenda.png',
              primaryColor: _primaryBlue,
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
                      ),
                    )
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : _buildAgendaList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAgendaForm(),
          backgroundColor: _primaryBlue,
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle entrée'),
        ),
        bottomNavigationBar: BottomNavigationBar(
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: _primaryBlue,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          items: [
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/images/Icone_Dashboard.png',
                width: isTabletDevice ? 60 : 40,
                height: isTabletDevice ? 60 : 40,
              ),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/images/maison_icon.png',
                width: isTabletDevice ? 60 : 40,
                height: isTabletDevice ? 60 : 40,
              ),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/images/Icone_Echanges.png',
                width: isTabletDevice ? 60 : 40,
                height: isTabletDevice ? 60 : 40,
              ),
              label: 'Messages',
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaEntry {
  _AgendaEntry({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.visibleTo,
    required this.createdBy,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final List<String> visibleTo;
  final String createdBy;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isShared =>
      visibleTo.map((value) => value.toLowerCase()).contains('all');

  bool get hasSpecificTime => dueDate.hour != 0 || dueDate.minute != 0;

  bool isVisibleFor(String email) {
    final List<String> loweredVisibility =
        visibleTo.map((value) => value.toLowerCase()).toList();
    if (loweredVisibility.contains('all')) {
      return true;
    }
    if (email.isEmpty) {
      return false;
    }
    final String loweredEmail = email.toLowerCase();
    return loweredVisibility.contains(loweredEmail);
  }

  int get daysFromToday {
    final DateTime today = DateTime.now();
    final DateTime normalizedToday =
        DateTime(today.year, today.month, today.day);
    final DateTime normalizedDueDate =
        DateTime(dueDate.year, dueDate.month, dueDate.day);
    return normalizedDueDate.difference(normalizedToday).inDays;
  }

  factory _AgendaEntry.fromDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime dueDate = DateTime.now();
    final due = data['dueDate'];
    if (due is Timestamp) {
      dueDate = due.toDate();
    } else if (due is DateTime) {
      dueDate = due;
    } else if (due is String) {
      final parsed = DateTime.tryParse(due);
      if (parsed != null) dueDate = parsed;
    }

    final List<String> visibility = [];
    if (data['visibleTo'] is Iterable) {
      for (final item in (data['visibleTo'] as Iterable)) {
        if (item == null) continue;
        visibility.add(item.toString().toLowerCase());
      }
    }
    if (visibility.isEmpty) {
      visibility.add('all');
    }

    final String? notes = (data['notes'] as String?)?.trim();
    final createdAtRaw = data['createdAt'];
    final updatedAtRaw = data['updatedAt'];

    DateTime? createdAt;
    DateTime? updatedAt;

    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    }

    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    } else if (updatedAtRaw is DateTime) {
      updatedAt = updatedAtRaw;
    }

    return _AgendaEntry(
      id: id,
      title: (data['title'] ?? 'Sans titre').toString(),
      notes: notes?.isEmpty ?? true ? null : notes,
      dueDate: dueDate,
      visibleTo: visibility,
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
