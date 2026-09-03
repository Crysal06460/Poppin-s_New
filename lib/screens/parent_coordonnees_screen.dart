import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // AJOUT en haut du fichier
import 'package:flutter/services.dart';

class ParentCoordonneesScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String structureId;

  const ParentCoordonneesScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.structureId,
  }) : super(key: key);

  @override
  _ParentCoordonneesScreenState createState() =>
      _ParentCoordonneesScreenState();
}

class _ParentCoordonneesScreenState extends State<ParentCoordonneesScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  Map<String, dynamic> parentInfo = {};
  Map<String, dynamic> parentAddress = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Design System 2025 - Palette officielle de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2

  // Couleurs dérivées pour le design system
  static const Color surfaceColor = Color(0xFFFAFBFC);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadParentInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ✅ Méthode pour formater le numéro de téléphone pour l'affichage
  String _formatPhoneDisplay(String phone) {
    // Supprimer tout caractère non numérique
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Si la longueur n'est pas paire ou trop courte, retourner tel quel
    if (digits.length < 2) return phone;
    
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 2 == 0) {
            buffer.write(' ');
        }
        buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Future<void> _loadParentInfo() async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? {};

        final parent1Data =
            Map<String, dynamic>.from(data['parent1'] ?? const {});
        final parent2Data =
            Map<String, dynamic>.from(data['parent2'] ?? const {});
        final parent1Addr =
            Map<String, dynamic>.from(data['parentAddress'] ?? const {});
        final parent2Addr =
            Map<String, dynamic>.from(data['parent2Address'] ?? const {});

        final currentEmail =
            FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
        bool shouldPersistParent1 = false;
        if (currentEmail.isNotEmpty &&
            (parent1Data['email'] == null ||
                parent1Data['email'].toString().isEmpty)) {
          parent1Data['email'] = currentEmail;
          shouldPersistParent1 = true;
        }

        setState(() {
          parentInfo = {
            'parent1': parent1Data,
            'parent2': parent2Data,
          };
          parentAddress = {
            'parent1': parent1Addr,
            'parent2': parent2Addr,
          };
          isLoading = false;
        });

        if (shouldPersistParent1) {
          await childDoc.reference
              .set({'parent1': parent1Data}, SetOptions(merge: true));
        }

        _animationController.forward();
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildParentSection(String parentKey, String parentTitle, int index) {
    final parent =
        Map<String, dynamic>.from(parentInfo[parentKey] ?? const {});
    final parentAddr =
        Map<String, dynamic>.from(parentAddress[parentKey] ?? const {});
    final bool hasInfo = parent.isNotEmpty || parentAddr.isNotEmpty;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryBlue.withOpacity(0.08),
                          brightCyan.withOpacity(0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryBlue, brightCyan],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parentTitle,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              if (hasInfo &&
                                  ((parent['firstName'] ?? '')
                                          .toString()
                                          .isNotEmpty ||
                                      (parent['lastName'] ?? '')
                                          .toString()
                                          .isNotEmpty))
                                Text(
                                  "${parent['firstName'] ?? ''} ${parent['lastName'] ?? ''}"
                                      .trim(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                )
                              else
                                Text(
                                  'Informations non renseignées',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showEditParentDetailsDialog(parentKey),
                          icon: Icon(
                            hasInfo ? Icons.edit : Icons.add_circle_outline,
                            color: primaryBlue,
                          ),
                          tooltip: hasInfo
                              ? 'Modifier les informations'
                              : 'Ajouter les informations',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (!hasInfo) ...[
                          Text(
                            'Aucune information n\'a encore été renseignée pour ce parent.',
                            style: TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showEditParentDetailsDialog(parentKey),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit),
                              label: const Text('Renseigner les informations'),
                            ),
                          ),
                        ],
                        if (hasInfo) ...[
                          if (parent['email'] != null &&
                              parent['email'].toString().isNotEmpty) ...[
                            _buildModernInfoRow(
                              Icons.email_rounded,
                              "Email",
                              parent['email'].toString(),
                              Colors.indigo,
                              isClickable: true,
                              onTap: () => _handleEmailTap(
                                  parent['email'].toString(), parentKey),
                              isEditable: true,
                              onEdit: () => _showEditEmailDialog(parentKey),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _resendInvitation(parentKey),
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text("Renvoyer l'invitation"),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryBlue,
                                  backgroundColor:
                                      primaryBlue.withOpacity(0.08),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                          ],
                          if (parent['phone'] != null &&
                              parent['phone'].toString().isNotEmpty)
                            _buildModernInfoRow(
                              Icons.phone_rounded,
                              "Téléphone",
                              _formatPhoneDisplay(parent['phone'].toString()),
                              Colors.green,
                              isEditable: true,
                              onEdit: () => _showEditPhoneDialog(parentKey),
                            ),
                          if (parentAddr.isNotEmpty)
                            _buildModernInfoRow(
                              Icons.location_on_rounded,
                              "Adresse",
                              _formatAddress(parentAddr),
                              Colors.orange,
                              isEditable: true,
                              onEdit: () => _showEditAddressDialog(parentKey),
                            ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showEditParentDetailsDialog(parentKey),
                              icon: const Icon(Icons.manage_accounts),
                              label: const Text(
                                  'Modifier les informations générales'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryBlue,
                                side: BorderSide(color: primaryBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Carte CTA pour ajouter un Parent 2 si manquant
  Widget _buildAddParent2Card() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue.withOpacity(0.08), brightCyan.withOpacity(0.04)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryBlue, brightCyan],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.person_add_alt_1, color: Colors.white),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ajouter un second parent',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary)),
                      SizedBox(height: 4),
                      Text(
                        'Renseignez ses coordonnées pour l\'inviter et partager le suivi.',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddSecondParentDialog,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(Icons.edit, color: primaryBlue),
                    label: Text('Renseigner le Parent 2',
                        style: TextStyle(
                            color: primaryBlue, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showAddSecondParentDialog() async {
    final firstCtl = TextEditingController();
    final lastCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final emailCtl = TextEditingController();
    String? error;

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Ajouter le Parent 2',
                style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(firstCtl, 'Prénom', TextInputType.name, hint: 'Ex: Marie'),
                  SizedBox(height: 10),
                  _buildTextField(lastCtl, 'Nom', TextInputType.name, hint: 'Ex: Dupont'),
                  SizedBox(height: 10),
                  _buildTextField(
                    phoneCtl,
                    'Téléphone',
                    TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    hint: '10 chiffres (ex: 0612345678)'
                  ),
                  SizedBox(height: 10),
                  _buildTextField(
                    emailCtl,
                    'Email',
                    TextInputType.emailAddress,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\s]')),
                    ],
                    hint: 'prenom.nom@email.fr'
                  ),
                  if (error != null) ...[
                    SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(error!, style: TextStyle(color: primaryRed)),
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  final email = emailCtl.text.trim().toLowerCase();
                  final first = firstCtl.text.trim();
                  final last = lastCtl.text.trim();
                  final phone = phoneCtl.text.trim();
                  final emailRe = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
                  if (first.isEmpty || last.isEmpty) {
                    setState(() => error = 'Prénom et nom sont requis');
                    return;
                  }
                  if (email.isEmpty || !emailRe.hasMatch(email)) {
                    setState(() => error = 'Email invalide');
                    return;
                  }
                  // Téléphone facultatif mais si fourni => 10 chiffres
                  final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
                  if (phone.isNotEmpty && phoneDigits.length != 10) {
                    setState(() => error = 'Téléphone invalide (10 chiffres requis)');
                    return;
                  }
                  setState(() => error = null);
                  Navigator.pop(context, true);
                  // Sauvegarder après fermeture pour éviter multiple setState du dialog
                  _saveSecondParent({'firstName': first, 'lastName': last, 'phone': phoneDigits, 'email': email});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Enregistrer'),
              ),
            ],
          );
        });
      },
    );

    if (confirmed == true) {
      // Un snackbar est géré dans _saveSecondParent
    }
  }

  Future<void> _showEditParentDetailsDialog(String parentKey) async {
    final parent =
        Map<String, dynamic>.from(parentInfo[parentKey] ?? const {});
    final parentAddr =
        Map<String, dynamic>.from(parentAddress[parentKey] ?? const {});

    final firstCtl =
        TextEditingController(text: (parent['firstName'] ?? '').toString());
    final lastCtl =
        TextEditingController(text: (parent['lastName'] ?? '').toString());
    final emailCtl = TextEditingController(
        text: (parent['email'] ?? '').toString().toLowerCase());
    final phoneCtl =
        TextEditingController(text: (parent['phone'] ?? '').toString());
    final addressCtl = TextEditingController(
        text: (parentAddr['address'] ?? '').toString());
    final postalCtl = TextEditingController(
        text: (parentAddr['postalCode'] ?? '').toString());
    final cityCtl = TextEditingController(
        text: (parentAddr['city'] ?? '').toString());

    final previousEmail = (parent['email'] ?? '').toString().toLowerCase();
    String? error;
    bool isSaving = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(
                parentKey == 'parent2'
                    ? 'Renseigner le Parent 2'
                    : 'Renseigner le Parent 1',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(firstCtl, 'Prénom', TextInputType.name,
                        hint: 'Ex: Marie'),
                    SizedBox(height: 12),
                    _buildTextField(lastCtl, 'Nom', TextInputType.name,
                        hint: 'Ex: Dupont'),
                    SizedBox(height: 12),
                    _buildTextField(
                      emailCtl,
                      'Email',
                      TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'[\s]')),
                      ],
                      hint: 'prenom.nom@email.fr',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      phoneCtl,
                      'Téléphone (facultatif)',
                      TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      hint: '10 chiffres (ex: 0612345678)',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(addressCtl, 'Adresse', TextInputType.text,
                        hint: 'Numéro et rue'),
                    SizedBox(height: 12),
                    _buildTextField(
                      postalCtl,
                      'Code postal',
                      TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      cityCtl,
                      'Ville',
                      TextInputType.text,
                      hint: 'Votre ville',
                    ),
                    if (error != null) ...[
                      SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          error!,
                          style: const TextStyle(color: primaryRed),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text('Annuler', style: TextStyle(color: textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final first = firstCtl.text.trim();
                          final last = lastCtl.text.trim();
                          final email = emailCtl.text.trim().toLowerCase();
                          final phoneDigits =
                              phoneCtl.text.replaceAll(RegExp(r'\D'), '');

                          if (first.isEmpty || last.isEmpty) {
                            setState(() =>
                                error = 'Prénom et nom sont requis');
                            return;
                          }

                          if (email.isEmpty ||
                              !RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                                  .hasMatch(email)) {
                            setState(() => error = 'Email invalide');
                            return;
                          }

                          if (phoneCtl.text.isNotEmpty &&
                              phoneDigits.length != 10) {
                            setState(() =>
                                error = 'Téléphone invalide (10 chiffres requis)');
                            return;
                          }

                          setState(() {
                            error = null;
                            isSaving = true;
                          });

                          final info = <String, String>{
                            'firstName': first,
                            'lastName': last,
                            'email': email,
                            if (phoneDigits.isNotEmpty) 'phone': phoneDigits,
                          };

                          final address = <String, String>{
                            if (addressCtl.text.trim().isNotEmpty)
                              'address': addressCtl.text.trim(),
                            if (postalCtl.text.trim().isNotEmpty)
                              'postalCode': postalCtl.text.trim(),
                            if (cityCtl.text.trim().isNotEmpty)
                              'city': cityCtl.text.trim(),
                          };

                          try {
                            await _saveParentDetails(
                              parentKey,
                              info,
                              address,
                              previousEmail: previousEmail,
                            );

                            if (!mounted) return;
                            Navigator.pop(context, true);

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  parentKey == 'parent2'
                                      ? 'Parent 2 mis à jour'
                                      : 'Informations parent 1 mises à jour',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setState(() {
                              error = e.toString();
                              isSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveParentDetails(
    String parentKey,
    Map<String, String> info,
    Map<String, String> address, {
    String? previousEmail,
  }) async {
    final childRef = FirebaseFirestore.instance
        .collection('structures')
        .doc(widget.structureId)
        .collection('children')
        .doc(widget.childId);

    final parentField = parentKey == 'parent2' ? 'parent2' : 'parent1';
    final addressField =
        parentKey == 'parent2' ? 'parent2Address' : 'parentAddress';

    await childRef.set(
      {
        parentField: info,
        addressField: address,
      },
      SetOptions(merge: true),
    );

    setState(() {
      parentInfo[parentKey] = info;
      parentAddress[parentKey] = address;
    });

    final email = (info['email'] ?? '').toLowerCase();
    final currentEmail =
        FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

    final shouldSendInvitation = email.isNotEmpty &&
        (previousEmail == null ||
            email != previousEmail.toLowerCase() || previousEmail.isEmpty) &&
        !(parentKey == 'parent1' && email == currentEmail);

    if (shouldSendInvitation) {
      await _queueParentInvitationEmail(parentKey, email);
    }
  }

  Widget _buildTextField(TextEditingController ctl, String label, TextInputType type,
      {List<TextInputFormatter>? inputFormatters, String? hint}) {
    return TextField(
      controller: ctl,
      keyboardType: type,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryBlue, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _saveSecondParent(Map<String, String> p2) async {
    try {
      final childRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId);

      await childRef.update({'parent2': p2});

      setState(() {
        parentInfo['parent2'] = p2;
      });

      // Si email fourni, créer/mettre à jour l'user parent et file invitation
      final email = p2['email'] ?? '';
      String msg = 'Parent 2 ajouté et enregistré';
      if (email.isNotEmpty) {
        await _queueParentInvitationEmail('parent2', email);
        msg = 'Parent 2 ajouté. Invitation envoyée à $email';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: $e'),
            backgroundColor: primaryRed,
          ),
        );
      }
    }
  }

  // Méthode corrigée pour les infos avec support email cliquable
  Widget _buildModernInfoRow(
    IconData icon,
    String label,
    String value,
    Color iconColor, {
    bool isClickable = false,
    VoidCallback? onTap,
    bool isEditable = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône avec design moderne
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),

                SizedBox(width: 16),

                // Contenu texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicateur pour email cliquable
                if (isClickable) ...[
                  SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryBlue, brightCyan],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
                if (isEditable) ...[
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.edit, color: iconColor),
                    tooltip: 'Modifier',
                    onPressed: onEdit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditEmailDialog(String parentKey) async {
    final parent = Map<String, dynamic>.from(parentInfo[parentKey] ?? {});
    final TextEditingController controller =
        TextEditingController(text: (parent['email'] ?? '').toString());

    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier l\'email du ${parentKey == 'parent1' ? 'parent 1' : 'parent 2'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\s]'))],
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'parent@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty) return;

    // Validation simple
    final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    if (!emailRegex.hasMatch(newEmail)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adresse email invalide'), backgroundColor: primaryRed),
        );
      }
      return;
    }

    try {
      await _updateParentEmail(parentKey, newEmail.toLowerCase());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email mis à jour. Invitation renvoyée.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour: $e'), backgroundColor: primaryRed),
        );
      }
    }
  }

  Future<void> _updateParentEmail(String parentKey, String email) async {
    // Mise à jour Firestore enfant
    final childRef = FirebaseFirestore.instance
        .collection('structures')
        .doc(widget.structureId)
        .collection('children')
        .doc(widget.childId);

    final fieldPath = parentKey == 'parent2' ? 'parent2.email' : 'parent1.email';
    await childRef.update({fieldPath: email});

    // Etat local
    setState(() {
      parentInfo[parentKey] = {
        ...?parentInfo[parentKey],
        'email': email,
      };
    });

    await _queueParentInvitationEmail(parentKey, email);
  }

  Future<void> _queueParentInvitationEmail(String parentKey, String email) async {
    // Garde-fou : ne jamais écraser le compte d'une professionnelle existante
    // (ex: fondatrice qui saisit par erreur l'email d'une collègue MAM au lieu
    // du vrai parent) avec role:'parent'.
    final existingUserDoc =
        await FirebaseFirestore.instance.collection('users').doc(email).get();
    if (existingUserDoc.exists) {
      final existingRole = (existingUserDoc.data()?['role'] ?? '').toString();
      const professionalRoles = {'admin', 'mamMember', 'assistant', 'structure'};
      if (professionalRoles.contains(existingRole)) {
        throw Exception(
            "Cet email est déjà utilisé par un compte professionnel. Veuillez vérifier l'adresse saisie.");
      }
    }

    // Récupération infos
    String structureName = 'Structure d\'accueil';
    try {
      final s = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .get();
      structureName = (s.data() ?? {})['structureName'] ?? structureName;
    } catch (_) {}

    final parent = Map<String, dynamic>.from(parentInfo[parentKey] ?? {});
    final firstName = (parent['firstName'] ?? '').toString();
    final lastName = (parent['lastName'] ?? '').toString();

    // Enregistrer une entrée d'invitation (suivi)
    await FirebaseFirestore.instance.collection('invitations').add({
      'email': email,
      'type': 'parent',
      'structureId': widget.structureId,
      'structureName': structureName,
      'childId': widget.childId,
      'childName': widget.childName,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
      'status': 'active',
    });

    // Upsert doc user parent minimal
    await FirebaseFirestore.instance.collection('users').doc(email).set({
      'role': 'parent',
      'email': email,
      'children': FieldValue.arrayUnion([widget.childId]),
      'structureId': widget.structureId,
      'structureName': structureName,
      'childName': widget.childName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Queue email via emailQueue
    final templateData = {
      'firstName': firstName,
      'lastName': lastName,
      'childName': widget.childName,
      'childId': widget.childId,
      'structureName': structureName,
      'structureId': widget.structureId,
      'androidLink': 'https://play.google.com/store/apps/details?id=com.example.poppins_app',
      'iosLink': 'https://apps.apple.com/us/app/poppins/id6744274953',
      'email': email,
      'year': DateTime.now().year.toString(),
    };

    await FirebaseFirestore.instance.collection('emailQueue').add({
      'to': email,
      'template': 'parent-invitation',
      'subject': "Invitation Poppins - Pour ${widget.childName}",
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'priority': 'high',
      'retryCount': 0,
      'templateData': templateData,
    });
  }

  Future<void> _resendInvitation(String parentKey) async {
    try {
      final parent = Map<String, dynamic>.from(parentInfo[parentKey] ?? {});
      final email = (parent['email'] ?? '').toString().toLowerCase().trim();
      if (email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aucune adresse email à utiliser'), backgroundColor: primaryRed),
          );
        }
        return;
      }
      await _queueParentInvitationEmail(parentKey, email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation renvoyée à $email'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: primaryRed),
        );
      }
    }
  }

  Future<void> _showEditPhoneDialog(String parentKey) async {
    final parent = Map<String, dynamic>.from(parentInfo[parentKey] ?? {});
    final TextEditingController controller =
        TextEditingController(text: (parent['phone'] ?? '').toString());

    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier le téléphone du ${parentKey == 'parent1' ? 'parent 1' : 'parent 2'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: 'Téléphone',
            hintText: '10 chiffres (ex: 0612345678)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newPhone == null) return;
    final cleaned = newPhone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty || cleaned.length != 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Numéro invalide (10 chiffres requis)'), backgroundColor: primaryRed),
        );
      }
      return;
    }

    await _updateParentPhone(parentKey, cleaned);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Téléphone mis à jour'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _updateParentPhone(String parentKey, String phone) async {
    final childRef = FirebaseFirestore.instance
        .collection('structures')
        .doc(widget.structureId)
        .collection('children')
        .doc(widget.childId);
    final fieldPath = parentKey == 'parent2' ? 'parent2.phone' : 'parent1.phone';
    await childRef.update({fieldPath: phone});
    setState(() {
      parentInfo[parentKey] = {
        ...?parentInfo[parentKey],
        'phone': phone,
      };
    });
  }

  Future<void> _showEditAddressDialog(String parentKey) async {
    final addr = Map<String, dynamic>.from(parentAddress[parentKey] ?? {});
    final cAddress = TextEditingController(text: (addr['address'] ?? '').toString());
    final cPostal = TextEditingController(text: (addr['postalCode'] ?? '').toString());
    final cCity = TextEditingController(text: (addr['city'] ?? '').toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier l\'adresse du ${parentKey == 'parent1' ? 'parent 1' : 'parent 2'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: cAddress, decoration: InputDecoration(labelText: 'Adresse')), 
            SizedBox(height: 8),
            TextField(controller: cPostal, decoration: InputDecoration(labelText: 'Code postal'), keyboardType: TextInputType.number),
            SizedBox(height: 8),
            TextField(controller: cCity, decoration: InputDecoration(labelText: 'Ville')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Enregistrer')),
        ],
      ),
    );

    if (confirmed != true) return;
    await _updateParentAddress(parentKey, {
      'address': cAddress.text.trim(),
      'postalCode': cPostal.text.trim(),
      'city': cCity.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adresse mise à jour'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _updateParentAddress(String parentKey, Map<String, String> address) async {
    final childRef = FirebaseFirestore.instance
        .collection('structures')
        .doc(widget.structureId)
        .collection('children')
        .doc(widget.childId);

    final fieldPath = parentKey == 'parent2' ? 'parent2Address' : 'parentAddress';
    await childRef.update({fieldPath: address});
    setState(() {
      parentAddress[parentKey] = address;
    });
  }

  // Méthode corrigée pour gérer le clic sur l'email
  Future<void> _handleEmailTap(String email, String parentKey) async {
    // Créer l'URL mailto simple - JUSTE l'adresse email
    final mailtoUrl = 'mailto:$email';

    try {
      // Ouvrir l'app de messagerie native
      if (await canLaunchUrl(Uri.parse(mailtoUrl))) {
        await launchUrl(Uri.parse(mailtoUrl));
      } else {
        // Fallback si pas d'app mail configurée
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Aucune application de messagerie configurée'),
                  ),
                ],
              ),
              backgroundColor: primaryRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Erreur: ${e.toString()}')),
              ],
            ),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  String _formatAddress(Map<String, dynamic> parentAddr) {
    List<String> addressParts = [];

    if (parentAddr['address'] != null &&
        parentAddr['address'].toString().isNotEmpty) {
      addressParts.add(parentAddr['address'].toString());
    }

    if (parentAddr['postalCode'] != null &&
        parentAddr['postalCode'].toString().isNotEmpty) {
      if (parentAddr['city'] != null &&
          parentAddr['city'].toString().isNotEmpty) {
        addressParts.add("${parentAddr['postalCode']} ${parentAddr['city']}");
      } else {
        addressParts.add(parentAddr['postalCode'].toString());
      }
    } else if (parentAddr['city'] != null &&
        parentAddr['city'].toString().isNotEmpty) {
      addressParts.add(parentAddr['city'].toString());
    }

    return addressParts.join('\n');
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.1),
                  brightCyan.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.contact_page_rounded,
              size: 48,
              color: textSecondary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            "Aucune coordonnée disponible",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Les informations des parents n'ont pas encore été renseignées",
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showEditParentDetailsDialog('parent1'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Renseigner mes coordonnées'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: Column(
        children: [
          // Header moderne avec glassmorphism
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue,
                  brightCyan,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Row(
                  children: [
                    // Bouton retour avec effet glassmorphism
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Titre avec typographie moderne
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Coordonnées parents",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            widget.childName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal
          Expanded(
            child: isLoading
                ? Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: primaryBlue,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                : (parentInfo['parent1']?.isEmpty != false &&
                        parentInfo['parent2']?.isEmpty != false &&
                        parentAddress['parent1']?.isEmpty != false &&
                        parentAddress['parent2']?.isEmpty != false)
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Parent 1
                              _buildParentSection('parent1', 'Parent 1', 0),

                              // Parent 2
                              if ((parentInfo['parent2'] ?? {}).isNotEmpty ||
                                  (parentAddress['parent2'] ?? {}).isNotEmpty)
                                _buildParentSection('parent2', 'Parent 2', 1)
                              else
                                _buildAddParent2Card(),

                              // Espace pour le scroll final
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
