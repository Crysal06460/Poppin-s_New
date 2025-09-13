import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/models/delegation_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';
import 'package:poppins_app/services/delegation_service.dart';

class DelegationsScreen extends StatefulWidget {
  const DelegationsScreen({Key? key}) : super(key: key);

  @override
  State<DelegationsScreen> createState() => _DelegationsScreenState();
}

class _DelegationsScreenState extends State<DelegationsScreen> {
  final DelegationService _delegationService = DelegationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  List<Delegation> _pendingForMe = [];
  List<Delegation> _myProposals = [];
  List<Delegation> _acceptedForMe = [];
  List<Membre> _membres = [];
  List<Enfant> _enfants = [];
  String _structureId = '';

  static const Color primaryBlue = Color(0xFF3D9DF2);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      _structureId = await _delegationService.getCurrentStructureId();
      if (_structureId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Structure introuvable. Vérifiez votre connexion."),
            backgroundColor: Colors.red,
          ));
        }
        setState(() => _loading = false);
        return;
      }

      await Future.wait([_loadMembers(), _loadChildren()]);
      await _refreshLists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur de chargement: $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshLists() async {
    try {
      if (_structureId.isEmpty) return;
      // Pending for me on selected day
      _pendingForMe = await _delegationService.getPendingForMe(_selectedDate);
      // Accepted for me on selected day
      _acceptedForMe = await _delegationService.getAcceptedForMe(_selectedDate);
      // My proposals (for the day)
      final user = _auth.currentUser;
      final startTs = Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
      final endTs = Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).add(const Duration(days: 1)));
      final snap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('delegations')
          .where('createdBy', isEqualTo: user?.uid)
          .where('date', isGreaterThanOrEqualTo: startTs)
          .where('date', isLessThan: endTs)
          .get();
      _myProposals = snap.docs
          .map((d) => Delegation.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur de rafraîchissement: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _loadMembers() async {
    if (_structureId.isEmpty) return;
    try {
      final membersSnap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('members')
          .get();
      _membres = membersSnap.docs
          .map((doc) {
            final data = doc.data();
            return Membre(
                id: doc.id,
                nom: data['lastName'] ?? '',
                prenom: data['firstName'] ?? '',
                mamId: _structureId,
                role: data['role'] ?? 'membre',
                email: data['email'] ?? '');
          })
          .toList();
    } catch (e) {
      _membres = [];
    }
  }

  Future<void> _loadChildren() async {
    if (_structureId.isEmpty) return;
    try {
      final childrenSnap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('children')
          .get();
      _enfants = childrenSnap.docs
          .map((doc) {
            final data = doc.data();
            return Enfant(
              id: doc.id,
              nom: data['lastName'] ?? '',
              prenom: data['firstName'] ?? 'Sans nom',
              dateNaissance: data['birthDate'] != null
                  ? (data['birthDate'] as Timestamp).toDate()
                  : DateTime.now(),
              membresIds: data['assignedTo'] != null
                  ? List<String>.from(data['assignedTo'])
                  : [],
              photoUrl: data['photoUrl'],
              couleur: data['planningColor'],
            );
          })
          .toList();
    } catch (e) {
      _enfants = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Retour',
        ),
        title: const Text('Délégations', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        onPressed: _showProposeDialog,
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Demander'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDatePicker(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refreshLists(),
                    child: ListView(
                      children: [
                        _sectionTitle('À traiter (pour moi)'),
                        if (_pendingForMe.isEmpty)
                          const ListTile(
                            title: Text('Aucune demande pour ce jour'),
                          ),
                        ..._pendingForMe.map(_buildPendingTile),
                        const Divider(height: 24),
                        _sectionTitle('Acceptées (pour moi)'),
                        if (_acceptedForMe.isEmpty)
                          const ListTile(
                            title: Text('Aucune délégation acceptée ce jour'),
                          ),
                        ..._acceptedForMe.map(_buildAcceptedForMeTile),
                        const Divider(height: 24),
                        _sectionTitle('Mes demandes'),
                        if (_myProposals.isEmpty)
                          const ListTile(
                            title: Text('Aucune demande ce jour'),
                          ),
                        ..._myProposals.map(_buildMyProposalTile),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
              _refreshLists();
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              _refreshLists();
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'proposed':
        return 'demandée';
      case 'accepted':
        return 'acceptée';
      case 'declined':
        return 'refusée';
      case 'canceled':
        return 'annulée';
      case 'completed':
        return 'terminée';
      default:
        return status;
    }
  }

  Widget _buildPendingTile(Delegation d) {
    final enfant = _enfants.where((e) => e.id == d.childId).cast<Enfant?>().firstOrNull;
    final origin = _membres.where((m) => m.id == d.amOriginId).cast<Membre?>().firstOrNull;
    return Card(
      child: ListTile(
        title: Text(enfant != null ? '${enfant.prenom} ${enfant.nom}' : 'Enfant inconnu'),
        subtitle: Text('Demande de ${origin != null ? origin.prenom : '—'} • ${_statusLabel(d.status)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                final ok = await _delegationService.declineDelegation(d.id);
                if (ok) _refreshLists();
              },
              child: const Text('Refuser'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final ok = await _delegationService.acceptDelegation(d.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Délégation acceptée' : 'Echec de l\'acceptation')));
                if (ok) _refreshLists();
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              child: const Text('Accepter'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMyProposalTile(Delegation d) {
    final enfant = _enfants.where((e) => e.id == d.childId).cast<Enfant?>().firstOrNull;
    final delegate = _membres.where((m) => m.id == d.amDelegateId).cast<Membre?>().firstOrNull;
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(DateTime(d.date.year, d.date.month, d.date.day));
    final reason = (d.reason ?? '').trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: ListTile(
          title: Text(
            enfant != null ? '${enfant.prenom} ${enfant.nom}' : 'Enfant inconnu',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text('Demandée à : ${delegate != null ? delegate.prenom : '—'}'),
              Text('Date : $dateStr'),
              if (reason.isNotEmpty) Text('Motif : $reason'),
              Text('Statut : ${_statusLabel(d.status)}'),
            ],
          ),
          trailing: d.status == 'proposed'
              ? TextButton(
                  onPressed: () async {
                    final ok = await _delegationService.cancelDelegation(d.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            ok ? 'Demande annulée' : 'Annulation impossible')));
                    if (ok) _refreshLists();
                  },
                  child: const Text('Annuler'),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAcceptedForMeTile(Delegation d) {
    final enfant = _enfants.where((e) => e.id == d.childId).cast<Enfant?>().firstOrNull;
    final origin = _membres.where((m) => m.id == d.amOriginId).cast<Membre?>().firstOrNull;
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(DateTime(d.date.year, d.date.month, d.date.day));
    return Card(
      child: ListTile(
        title: Text(enfant != null ? '${enfant.prenom} ${enfant.nom}' : 'Enfant inconnu',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Accueilli par délégation • de ${origin?.prenom ?? '—'} • le $dateStr'),
      ),
    );
  }

  void _showProposeDialog() {
    final user = _auth.currentUser;
    if (user == null) return;
    final myUid = user.uid;
    final myEmail = (user.email ?? '').toLowerCase();

    // Identifier les IDs de membre correspondant à l'utilisateur courant
    final myMemberIds = _membres
        .where((m) => m.id == myUid || (m.email.isNotEmpty && m.email.toLowerCase() == myEmail))
        .map((m) => m.id)
        .toSet();

    // Enfants assignés à moi: match par memberId OU email (car assignedTo peut contenir des emails)
    final lowercaseEmail = myEmail.toLowerCase();
    final myChildren = _enfants.where((e) {
      return e.membresIds.any((idOrEmail) =>
          myMemberIds.contains(idOrEmail) ||
          idOrEmail.toLowerCase() == lowercaseEmail);
    }).toList();

    // Délégataires possibles: tous les autres membres de la MAM
    final delegates = _membres.where((m) => !myMemberIds.contains(m.id)).toList();

    // Proposer TOUS les enfants de la MAM (pas seulement ceux de l'assistante)
    final childrenForPicker = _enfants;
    String? selectedChildId =
        childrenForPicker.isNotEmpty ? childrenForPicker.first.id : null;
    String? selectedDelegateId = delegates.isNotEmpty ? delegates.first.id : null;
    DateTime selectedDate = _selectedDate;
    String? reason;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setStateModal) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Demander une délégation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDelegateId,
                  items: delegates
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text('${m.prenom} ${m.nom}'),
                          ))
                      .toList(),
                  onChanged: (v) => setStateModal(() => selectedDelegateId = v),
                  decoration: const InputDecoration(labelText: 'Demander à'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedChildId,
                  items: childrenForPicker
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.prenom} ${e.nom}'),
                          ))
                      .toList(),
                  onChanged: (v) => setStateModal(() => selectedChildId = v),
                  decoration:
                      const InputDecoration(labelText: 'Enfant à déléguer'),
                ),
                // Si aucun enfant assigné, la liste reste vide (pas d'astuce affichée)
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(selectedDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) setStateModal(() => selectedDate = picked);
                    },
                  ),
                ),
                TextField(
                  onChanged: (v) => reason = v,
                  decoration: const InputDecoration(
                    labelText: 'Motif (optionnel)',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedChildId == null || selectedDelegateId == null)
                        ? null
                        : () async {
                            final id = await _delegationService.proposeDelegation(
                              childId: selectedChildId!,
                              amDelegateId: selectedDelegateId!,
                              date: selectedDate,
                              reason: reason,
                            );
                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(id != null
                                    ? 'Demande envoyée'
                                    : 'Échec de la demande')));
                            _refreshLists();
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                    child: const Text('Envoyer la demande'),
                  ),
                )
              ],
            ),
          );
        }),
      ),
    );
  }
}

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
