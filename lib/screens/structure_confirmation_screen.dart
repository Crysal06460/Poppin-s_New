import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../services/firebase_trial_service.dart';

class StructureConfirmationScreen extends StatefulWidget {
  final String structureType;

  const StructureConfirmationScreen({Key? key, required this.structureType})
      : super(key: key);

  @override
  State<StructureConfirmationScreen> createState() =>
      _StructureConfirmationScreenState();
}

class _StructureConfirmationScreenState
    extends State<StructureConfirmationScreen> {
  static const Color _primaryBlue = Color(0xFF3D9DF2);
  static const Color _accentBlue = Color(0xFF1E75D8);
  static const Color _lightBackground = Color(0xFFF5F8FF);

  late String _rawStructureType;
  late String _formattedType;
  bool _isMam = false;
  int _selectedMamPlan = 3; // 3 => 2-3 membres, 4 => 4+ membres
  bool _isLoadingPlan = false;

  @override
  void initState() {
    super.initState();
    _rawStructureType = widget.structureType;
    _formattedType = _normalizeStructureType(_rawStructureType);
    _isMam = _formattedType.toLowerCase().contains('mam');
    if (_isMam) {
      _loadExistingMamPlan();
    }
  }

  String _normalizeStructureType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('mam')) {
      return 'MAM';
    }
    return 'AssistanteMaternelle';
  }

  Future<void> _loadExistingMamPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingPlan = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final dynamic preferred = data['mamPreferredPlan'] ??
              data['memberCount'] ??
              data['maxMemberCount'];
          if (preferred is int) {
            setState(() {
              _selectedMamPlan = preferred >= 4 ? 4 : 3;
            });
          }
        }
      }
    } catch (e) {
      print('⚠️ Impossible de charger le plan MAM: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    }
  }

  String _typeLabel() {
    if (!_isMam) {
      return "Assistant(e) Maternel(le)";
    }
    return _selectedMamPlan >= 4
        ? "MAM 4 membres ou plus"
        : "MAM 2 à 3 membres";
  }

  int _resolvedMamMemberCount() {
    if (!_isMam) return 1;
    return _selectedMamPlan >= 4 ? 4 : 3;
  }

  @override
  Widget build(BuildContext context) {
    print(
        "🔍 StructureConfirmationScreen - raw: '${widget.structureType}' => $_formattedType, plan=$_selectedMamPlan");

    return Scaffold(
      backgroundColor: _lightBackground,
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        elevation: 0,
        title: const Text(
          'Confirmation de la structure',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryBlue, _accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.domain_verification_rounded,
                size: 54,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Votre choix",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Type: ${_typeLabel()}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            if (_isMam) ...[
              const SizedBox(height: 24),
              _isLoadingPlan
                  ? const CircularProgressIndicator(color: _primaryBlue)
                  : _buildMamSelector(),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/structure-details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Modifier",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoadingPlan ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Confirmer",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMamSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisissez le nombre de membres de la MAM',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMamOption(
                value: 3,
                title: 'MAM 2 à 3 membres',
                subtitle: '',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMamOption(
                value: 4,
                title: 'MAM 4 membres',
                subtitle: '',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMamOption({
    required int value,
    required String title,
    required String subtitle,
  }) {
    final bool isSelected =
        _selectedMamPlan == value || (_selectedMamPlan >= 4 && value >= 4);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMamPlan = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Erreur d\'authentification. Veuillez vous reconnecter.'),
          ),
        );
        return;
      }

      final docRef =
          FirebaseFirestore.instance.collection('structures').doc(user.uid);
      final docSnapshot = await docRef.get();

      final int resolvedMembers = _resolvedMamMemberCount();

      final Map<String, dynamic> updates = {
        'structureType': _formattedType,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_isMam) {
        updates['mamPreferredPlan'] = _selectedMamPlan;
        updates['memberCount'] = resolvedMembers;
        updates['maxMemberCount'] = resolvedMembers;
      } else {
        updates['mamPreferredPlan'] = FieldValue.delete();
      }

      if (docSnapshot.exists) {
        await docRef.update(updates);
      } else {
        updates['email'] = user.email;
        updates['createdAt'] = FieldValue.serverTimestamp();
        updates['structureName'] = 'Nouvelle Structure';
        await docRef.set(updates, SetOptions(merge: true));
      }

      await FirebaseTrialService.ensureTrialForStructure(
        structureId: user.uid,
        ownerEmail: user.email,
        structureType: _formattedType,
        mamMemberCount: _isMam ? resolvedMembers : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Type de structure enregistré : ${_typeLabel()}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(milliseconds: 600), () {
        context.go('/structure-info', extra: {
          'structureType': _formattedType,
          'structureId': user.uid,
          if (_isMam) 'mamMembersCount': resolvedMembers,
        });
      });
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du type: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}
