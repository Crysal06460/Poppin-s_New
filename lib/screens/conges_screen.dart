// conges_screen.dart
//
// Permet à une assistante maternelle (solo ou membre MAM) de déclarer ses
// jours de congés à l'avance. Les enfants qui lui sont rattachés
// (assignedMemberEmail, ou tous si structure solo) sont alors marqués
// 'conge' dans structures/{id}/horaires/{date}/{childId} sur toute la
// période — le même champ actionType déjà utilisé par AbsenceHelper (jour
// courant) et le récap mensuel (statut ABSENT), auquel on ajoute ce nouveau
// statut distinct pour ne pas confondre avec une absence ponctuelle.
//
// En MAM, chaque membre ne déclare et n'affecte que ses propres enfants.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CongesScreen extends StatefulWidget {
  const CongesScreen({Key? key}) : super(key: key);

  @override
  State<CongesScreen> createState() => _CongesScreenState();
}

class _CongesScreenState extends State<CongesScreen> {
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);

  DateTimeRange? _selectedRange;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _errorMessage;

  String _structureId = '';
  String _currentUserEmail = '';
  bool _isMam = false;
  List<Map<String, dynamic>> _myChildren = [];
  final Set<String> _selectedChildIds = {};

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final String email = user.email?.toLowerCase() ?? '';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();
    final String structureId =
        (userDoc.data()?['structureId'] as String?)?.trim().isNotEmpty == true
            ? userDoc.data()!['structureId']
            : user.uid;

    final structureDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .get();
    final String structureType =
        (structureDoc.data()?['structureType'] ?? 'AssistanteMaternelle')
            .toString();
    final bool isMam = structureType.toUpperCase() == 'MAM';

    final childrenSnap = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .get();

    final List<Map<String, dynamic>> myChildren = childrenSnap.docs
        .map((doc) => {
              'id': doc.id,
              'firstName': doc.data()['firstName'] ?? 'Sans nom',
              'assignedMemberEmail': (doc.data()['assignedMemberEmail'] ?? '')
                  .toString()
                  .toLowerCase(),
            })
        .where((child) =>
            !isMam || child['assignedMemberEmail'] == email)
        .toList();

    if (!mounted) return;
    setState(() {
      _structureId = structureId;
      _currentUserEmail = email;
      _isMam = isMam;
      _myChildren = myChildren;
      _selectedChildIds
        ..clear()
        ..addAll(myChildren.map((c) => c['id'] as String));
      _isLoading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      helpText: 'Période de congés',
      saveText: 'Valider',
      confirmText: 'Valider',
    );
    if (range != null) {
      setState(() => _selectedRange = range);
    }
  }

  List<DateTime> _datesInRange(DateTimeRange range) {
    final List<DateTime> dates = [];
    DateTime cursor = DateTime(range.start.year, range.start.month, range.start.day);
    final DateTime end = DateTime(range.end.year, range.end.month, range.end.day);
    while (!cursor.isAfter(end)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  Future<void> _declarerConge() async {
    if (_selectedRange == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner une période.');
      return;
    }
    if (_selectedChildIds.isEmpty) {
      setState(() => _errorMessage =
          _myChildren.isEmpty
              ? 'Aucun enfant ne vous est rattaché.'
              : 'Sélectionnez au moins un enfant.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final dates = _datesInRange(_selectedRange!);
      final List<String> childIds = _selectedChildIds.toList();

      final congeRef = db
          .collection('structures')
          .doc(_structureId)
          .collection('conges')
          .doc();

      await congeRef.set({
        'memberEmail': _currentUserEmail,
        'startDateIso': DateFormat('yyyy-MM-dd').format(_selectedRange!.start),
        'endDateIso': DateFormat('yyyy-MM-dd').format(_selectedRange!.end),
        'childIds': childIds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Matérialisation horaires/{date}/{childId}.actionType = 'conge'.
      // On lit chaque doc du jour d'abord pour ne remplacer QUE la map de
      // l'enfant concerné (une vraie Map imbriquée, pas une clé en notation
      // pointée : le SDK Dart ne l'interprète pas comme un chemin, il crée
      // un champ plat littéral "childId.actionType" — piège vérifié en prod).
      final batch = db.batch();
      for (final date in dates) {
        final String dateId = DateFormat('yyyy-MM-dd').format(date);
        final docRef = db
            .collection('structures')
            .doc(_structureId)
            .collection('horaires')
            .doc(dateId);
        final docSnap = await docRef.get();
        final Map<String, dynamic> existingData = docSnap.data() ?? {};
        final Map<String, dynamic> updateData = {};
        for (final childId in childIds) {
          final Map<String, dynamic> existingChild =
              (existingData[childId] as Map<String, dynamic>?) ?? {};
          updateData[childId] = {
            ...existingChild,
            'actionType': 'conge',
            'congeId': congeRef.id,
          };
        }
        batch.set(docRef, updateData, SetOptions(merge: true));
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedRange = null;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Congés enregistrés'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Erreur : $e';
      });
    }
  }

  Future<void> _annulerConge(
    String congeId,
    String startDateIso,
    String endDateIso,
    List<dynamic> childIds,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce congé ?'),
        content: const Text(
          'Les enfants concernés réapparaîtront normalement sur toute la période.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer', style: TextStyle(color: primaryRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final DateTime start = DateFormat('yyyy-MM-dd').parse(startDateIso);
      final DateTime end = DateFormat('yyyy-MM-dd').parse(endDateIso);
      final dates = _datesInRange(DateTimeRange(start: start, end: end));

      final batch = db.batch();
      for (final date in dates) {
        final String dateId = DateFormat('yyyy-MM-dd').format(date);
        final docRef = db
            .collection('structures')
            .doc(_structureId)
            .collection('horaires')
            .doc(dateId);
        final docSnap = await docRef.get();
        final Map<String, dynamic> existingData = docSnap.data() ?? {};
        final Map<String, dynamic> updateData = {};
        for (final childId in childIds) {
          final String key = childId.toString();
          final Map<String, dynamic>? existingChild =
              existingData[key] as Map<String, dynamic>?;
          if (existingChild == null) continue;
          final Map<String, dynamic> cleaned = Map<String, dynamic>.from(
              existingChild)
            ..remove('actionType')
            ..remove('congeId');
          updateData[key] = cleaned;
        }
        if (updateData.isNotEmpty) {
          batch.set(docRef, updateData, SetOptions(merge: true));
        }
      }
      await batch.commit();

      await db
          .collection('structures')
          .doc(_structureId)
          .collection('conges')
          .doc(congeId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Congé annulé'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Congés',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBlue),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: primaryBlue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Sur la période choisie, vos enfants n'apparaîtront "
                            "plus dans les enfants du jour (accueil, horaires, "
                            "planning), et le récap mensuel indiquera "
                            '"Congés". En MAM, seuls vos propres enfants sont '
                            'concernés.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Déclarer un congé',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Période de congés',
                        prefixIcon: const Icon(Icons.date_range),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedRange == null
                            ? 'Sélectionner une période'
                            : "${DateFormat('dd/MM/yyyy').format(_selectedRange!.start)}"
                                ' → '
                                "${DateFormat('dd/MM/yyyy').format(_selectedRange!.end)}",
                      ),
                    ),
                  ),
                  if (_myChildren.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Enfants concernés',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._myChildren.map((child) {
                      final String id = child['id'] as String;
                      return CheckboxListTile(
                        value: _selectedChildIds.contains(id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedChildIds.add(id);
                            } else {
                              _selectedChildIds.remove(id);
                            }
                          });
                        },
                        title: Text(child['firstName'] as String),
                        activeColor: primaryBlue,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: primaryRed)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _declarerConge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Enregistrer ce congé',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Congés déclarés',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _structureId.isEmpty
                        ? null
                        : FirebaseFirestore.instance
                            .collection('structures')
                            .doc(_structureId)
                            .collection('conges')
                            .where('memberEmail', isEqualTo: _currentUserEmail)
                            .orderBy('startDateIso', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucun congé déclaré pour le moment.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final String startIso =
                              (data['startDateIso'] ?? '').toString();
                          final String endIso =
                              (data['endDateIso'] ?? '').toString();
                          final List<dynamic> childIds =
                              (data['childIds'] as List<dynamic>?) ?? [];
                          final String childNames = childIds
                              .map((id) => _myChildren.firstWhere(
                                    (c) => c['id'] == id,
                                    orElse: () => {'firstName': '?'},
                                  )['firstName'] as String)
                              .join(', ');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(Icons.beach_access, color: primaryBlue),
                              title: Text('$startIso → $endIso'),
                              subtitle: Text(childNames),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: primaryRed),
                                onPressed: () => _annulerConge(
                                  doc.id,
                                  startIso,
                                  endIso,
                                  childIds,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
