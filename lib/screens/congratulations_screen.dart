import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/firebase_trial_service.dart';

class CongratulationsScreen extends StatefulWidget {
  final String structureType;
  final bool skipStructureFlow;
  final String? prefilledEmail;

  const CongratulationsScreen({
    Key? key,
    required this.structureType,
    this.skipStructureFlow = false,
    this.prefilledEmail,
  }) : super(key: key);

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen> {
  static const Color _primaryBlue = Color(0xFF3D9DF2);
  static const Color _secondaryBlue = Color(0xFF1E75D8);
  static const Color _lightBackground = Color(0xFFF5F8FF);

  bool _isLoading = true;
  bool _effectiveSkipFlow = false;

  @override
  void initState() {
    super.initState();
    _checkExistingProfile();
  }

  Future<void> _checkExistingProfile() async {
    // Si on nous dit déjà de sauter via le paramètre, on respecte ce choix
    if (widget.skipStructureFlow) {
      if (mounted) {
        setState(() {
          _effectiveSkipFlow = true;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // ⚠️ GESTION UTILISATEUR NON AUTHENTIFIÉ (Retour Stripe Guest)
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // On ne peut pas vérifier le profil, donc on ne skip pas le flow,
            // mais l'UI gérera ce cas spécifiquement.
            _effectiveSkipFlow = false; 
          });
        }
        return;
      }

      print("🔍 Vérification profil existant pour: ${user.uid}");
      final doc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        // Logique: si le document existe et contient un nom de structure valide, c'est un profil actif.
        // Le backend (finalizeStripeSignup) initialise structureName à null pour les nouveaux.
        final dynamic sName = data?['structureName'];
        final bool hasValidStructureName = sName != null && sName.toString().trim().isNotEmpty;
          
        if (hasValidStructureName) {
          print("✅ Profil existant détecté -> Redirection Dashboard activée");
          if (mounted) {
              setState(() {
              _effectiveSkipFlow = true;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      print("⚠️ Erreur vérification profil: $e");
    }

    // Par défaut, si pas de profil trouvé ou erreur, on utilise le paramètre passé (false par défaut)
    if (mounted) {
      setState(() {
        _effectiveSkipFlow = widget.skipStructureFlow;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _lightBackground,
        body: const Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );
    }

    if (!_effectiveSkipFlow) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _RegistrationForm(
              structureType: widget.structureType,
              prefilledEmail: widget.prefilledEmail,
            ),
          ),
        ),
      );
    }

    // ÉCRAN STANDARD (AUTHENTIFIÉ)
    final String actionLabel =
        _effectiveSkipFlow ? "Accéder à mon tableau de bord" : "Continuer";

    return Scaffold(
      backgroundColor: _lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryBlue, _secondaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.celebration_rounded,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Félicitations !",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _effectiveSkipFlow
                                ? "Votre accès premium est maintenant actif."
                                : "Votre compte a été créé avec succès.",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      elevation: 3,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _effectiveSkipFlow
                                  ? "Abonnement activé 🎉"
                                  : "Merci de continuer la création de votre compte.",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _effectiveSkipFlow
                                  ? "Vous pouvez dès maintenant accéder à toutes vos fonctionnalités. Vos données sont conservées."
                                  : "Complétez quelques informations pour finaliser votre profil et profiter de Poppin’s.",
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (FirebaseAuth.instance.currentUser?.email != null) ...[
                      Text(
                        "Connecté en tant que :",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      Text(
                        FirebaseAuth.instance.currentUser!.email!,
                        style: TextStyle(
                          color: Colors.black87, 
                          fontSize: 15, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                           await FirebaseAuth.instance.signOut();
                           if (context.mounted) {
                             // Recharger la page pour afficher le formulaire
                             // Utiliser pushReplacement pour forcer le rebuild complet
                             context.pushReplacement('/congratulations');
                           }
                        },
                        child: const Text("Ce n'est pas vous ? Créer un compte", style: TextStyle(color: _primaryBlue)),
                      )
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Si on a un profil existant, on redirige vers le dashboard
                    if (_effectiveSkipFlow) {
                      context.go('/home');
                    } else {
                      // Safety net: éviter StructureConfirmationScreen même si profil incomplet,
                      // le dashboard gérera la suite.
                      context.go('/home');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationForm extends StatefulWidget {
  final String structureType;
  final String? prefilledEmail;
  const _RegistrationForm({required this.structureType, this.prefilledEmail});

  @override
  State<_RegistrationForm> createState() => _RegistrationFormState();
}



class _RegistrationFormState extends State<_RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController(); 
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  List<String> _citySuggestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
    // Ecouter le code postal pour l'autocomplétion
    _zipController.addListener(_onZipChanged);
    
    // On lance la vérification en arrière-plan seulement si déjà connecté
    _verifySubscription();
  }

  // Stocke le résultat de la vérification d'abonnement
  String? _verifiedStructureType;
  int? _verifiedMaxMembers;

  Future<void> _verifySubscription({String? email, String? uid}) async {
    final result = await FirebaseTrialService.verifySubscription(email: email, uid: uid);
    
    if (result.isValid) {
      _verifiedStructureType = result.structureType;
      _verifiedMaxMembers = result.maxMemberCount;
      print("🔒 Abonnement confirmé via Service: $_verifiedStructureType ($_verifiedMaxMembers membres).");
    }
  }

  void _onZipChanged() {
    final zip = _zipController.text;
    if (zip.length == 5) {
      _fetchCities(zip);
    }
  }

  Future<void> _fetchCities(String postalCode) async {
    final url = Uri.parse('https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> cities = json.decode(response.body);
        final List<String> cityNames = cities.map((c) => c['nom'].toString()).toList();
        
        setState(() {
          _citySuggestions = cityNames;
          if (cityNames.isNotEmpty) {
             // Si une seule ville, on la sélectionne d'office
             if (cityNames.length == 1) {
               _cityController.text = cityNames.first;
             } else {
               // Sinon on vide pour forcer le choix, sauf si la valeur actuelle est déjà dans la liste
               if (!cityNames.contains(_cityController.text)) {
                 _cityController.clear();
               }
             }
          } else {
            _citySuggestions = [];
          }
        });
      }
    } catch (e) {
      print("Erreur API Gouv: $e");
    }
  }

  // Helper pour vérifier si la ville saisie est valide
  bool get _cityNames => _citySuggestions.contains(_cityController.text);

  @override
  void dispose() {
    _zipController.removeListener(_onZipChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String email = _emailController.text.trim().toLowerCase();
      User? currentUser = FirebaseAuth.instance.currentUser;

      // SÉCURITÉ TESTEURS : Si un utilisateur est déjà connecté (non anonyme) 
      // et qu'on saisit un AUTRE email, c'est qu'on veut créer un NOUVEAU compte.
      // On déconnecte le précédent pour éviter d'écraser son compte.
      if (currentUser != null && !currentUser.isAnonymous && currentUser.email != null && currentUser.email != email) {
          print("⚠️ Email différent du user connecté (${currentUser.email} vs $email). Déconnexion pour créer un nouveau compte.");
          await FirebaseAuth.instance.signOut();
          currentUser = null;
      }

      if (email.isEmpty && currentUser?.email != null) {
        email = currentUser!.email!.trim().toLowerCase();
      }

      User? resolvedUser = currentUser;
      
      // CAS 1: Utilisateur Anonyme -> ON UPGRADE LE COMPTE
      if (resolvedUser != null && resolvedUser.isAnonymous) {
         try {
           print("👤 Utilisateur anonyme détecté (${resolvedUser.uid}). Tentative de liaison du compte email...");
           AuthCredential credential = EmailAuthProvider.credential(email: email, password: _passwordController.text);
           final result = await resolvedUser.linkWithCredential(credential);
           resolvedUser = result.user;
           print("✅ Compte anonyme converti avec succès: ${resolvedUser?.email}");
         } on FirebaseAuthException catch (e) {
           print("❌ Erreur liaison ($e).");
           if (e.code == 'credential-already-in-use') {
              print("⚠️ Cet email est déjà utilisé. Tentative de connexion sur le compte existant...");
              try {
                  final signInResult = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: _passwordController.text);
                  resolvedUser = signInResult.user;
                  print("✅ Connexion réussie sur le compte existant: ${resolvedUser?.email}");
              } catch (signInError) {
                  throw Exception("Impossible de lier ce compte : l'email existe déjà et le mot de passe est incorrect.");
              }
           } else {
              // Autres erreurs (ex: user-not-found sur l'anonyme), on repart de zéro
              resolvedUser = null; 
           }
         } catch (e) {
           print("❌ Erreur générique liaison ($e). Création standard...");
           resolvedUser = null;
         }
      } 
      
      // CAS 2: Pas d'utilisateur (ou fallback ci-dessus) -> Création standard
      if (resolvedUser == null) {
        try {
          final userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text,
          );
          resolvedUser = userCredential.user;
        } on FirebaseAuthException catch (e) {
             if (e.code == 'email-already-in-use') {
                 print("⚠️ Email déjà pris lors de la création. Tentative de connexion...");
                 final signInResult = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: _passwordController.text);
                 resolvedUser = signInResult.user;
             } else {
               rethrow;
             }
        }
      }
      // CAS 3: Utilisateur déjà connecté et non anonyme -> On utilise le compte tel quel (rare ici)
      
      if (resolvedUser == null) {
        throw StateError('Utilisateur non disponible');
      }

      final uid = resolvedUser.uid;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // 2. Création/Mise à jour Doc Structure
      final structureRef = FirebaseFirestore.instance.collection('structures').doc(uid);
      final structureSnap = await structureRef.get();
      
      dynamic createdAt = FieldValue.serverTimestamp();
      if (structureSnap.exists && structureSnap.data()?['createdAt'] != null) {
        createdAt = structureSnap.data()!['createdAt'];
      }

      // 🛑 LOGIQUE DE DECISION FINALE
      String finalStructureType;
      int finalMaxMembers;

      for (int attempt = 0;
          attempt < 3 && _verifiedStructureType == null;
          attempt++) {
        await _verifySubscription(email: email, uid: uid);
        if (_verifiedStructureType == null) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (_verifiedStructureType != null) {
        // ✅ Priorité absolue à l'abonnement payé
        finalStructureType = _verifiedStructureType!;
        finalMaxMembers = _verifiedMaxMembers ?? 1;
        print(
            "✅ Création structure basée sur abonnement: $finalStructureType ($finalMaxMembers membres)");
      } else if (structureSnap.exists) {
        final existing = structureSnap.data() ?? <String, dynamic>{};
        final String existingType =
            (existing['structureType'] ?? 'assistante_maternelle').toString();
        final dynamic existingMaxRaw = existing['maxMemberCount'];
        int? existingMax;
        if (existingMaxRaw is int) {
          existingMax = existingMaxRaw;
        } else if (existingMaxRaw is num) {
          existingMax = existingMaxRaw.toInt();
        } else if (existingMaxRaw is String) {
          existingMax = int.tryParse(existingMaxRaw);
        }
        finalStructureType = existingType;
        finalMaxMembers = existingMax ?? 1;
        print(
            "⚠️ Abonnement non confirmé, conservation structure existante: $finalStructureType ($finalMaxMembers membres)");
      } else {
        finalStructureType = 'assistante_maternelle';
        finalMaxMembers = 1;
        print(
            "⚠️ Abonnement non confirmé, fallback sécurisé: $finalStructureType ($finalMaxMembers membres)");
      }

      await structureRef.set({
        'email': _emailController.text.trim(),
        'ownerEmail': _emailController.text.trim(), 
        'firstName': firstName,
        'lastName': lastName,
        'displayName': "$firstName $lastName",
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'address': _addressController.text.trim(),
        'postalCode': _zipController.text.trim(), // CORRECTION: Nom standardisé
        'zipCode': _zipController.text.trim(), // Legacy support (optionnel)
        'city': _cityController.text.trim(),
        'structureType': finalStructureType,
        'maxMemberCount': finalMaxMembers,
        'createdAt': createdAt, 
        'creationDate': createdAt, 
        'source': 'app_registration_poppins_redirection',
      }, SetOptions(merge: true));
      
      final memberRef = structureRef.collection('members').doc('member_1');
      await memberRef.set({
        'uid': uid,
        'email': _emailController.text.trim(),
        'firstName': firstName,
        'lastName': lastName,
        'phone': _phoneController.text.trim(),
        'role': 'owner',
        'isFounder': true,
        'memberNumber': 1,
        'createdAt': createdAt,
      }, SetOptions(merge: true));

      await resolvedUser.updateDisplayName("$firstName $lastName");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(email.isNotEmpty ? email : uid)
          .set({
        'structureId': uid,
        'role': 'structure',
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
         context.go('/home');
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
         setState(() {
           _errorMessage = e.message ?? "Erreur lors de l'inscription.";
         });
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _errorMessage = "Une erreur inattendue est survenue.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Finalisez votre inscription 📝",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Votre paiement est validé. Créez votre compte pour accéder à l'application.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          
          const SizedBox(height: 24),

          Row(children: [
             Expanded(child: _buildTextField("Prénom", _firstNameController)),
             const SizedBox(width: 12),
             Expanded(child: _buildTextField("Nom", _lastNameController)),
          ]),
          
          // Email
          _buildTextField(
            "Email", 
            _emailController, 
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.isEmpty) return "Requis";
              if (!val.contains('@') || !val.contains('.')) return "Email invalide";
              return null;
            }
          ),

          // Téléphone
          _buildTextField(
            "Téléphone", 
            _phoneController, 
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            validator: (val) {
              if (val == null || val.isEmpty) return "Requis";
              if (val.length != 10) return "10 chiffres requis";
              return null;
            }
          ),

          // Adresse
          _buildTextField("Adresse", _addressController),

          // CP / Ville
          Row(children: [
             Expanded(child: _buildTextField(
               "Code Postal", 
               _zipController, 
               keyboardType: TextInputType.number,
               inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)]
             )),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // Champ Ville custom avec PopupMenu
                   GestureDetector(
                     onTap: () {
                       if (_citySuggestions.length > 1) {
                         // Afficher le popup menu
                         final RenderBox renderBox = context.findRenderObject() as RenderBox;
                         final offset = renderBox.localToGlobal(Offset.zero);
                         showMenu(
                           context: context,
                           position: RelativeRect.fromLTRB(
                             offset.dx + renderBox.size.width / 2, // Position approx
                             offset.dy + renderBox.size.height,
                             offset.dx + renderBox.size.width,
                             offset.dy,
                           ),
                           items: _citySuggestions.map((String city) {
                             return PopupMenuItem<String>(
                               value: city,
                               child: Text(city),
                             );
                           }).toList(),
                         ).then((value) {
                           if (value != null) {
                             setState(() {
                               _cityController.text = value;
                             });
                           }
                         });
                       }
                     },
                     child: AbsorbPointer(
                       absorbing: _citySuggestions.length > 1,
                       child: TextFormField(
                         controller: _cityController,
                         validator: (val) {
                           if (val == null || val.isEmpty) return "Requis";
                           return null;
                         },
                         decoration: InputDecoration(
                           labelText: "Ville",
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           suffixIcon: _citySuggestions.length > 1
                               ? PopupMenuButton<String>(
                                   icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3D9DF2)),
                                   onSelected: (String value) {
                                     setState(() {
                                       _cityController.text = value;
                                     });
                                   },
                                   itemBuilder: (BuildContext context) {
                                     return _citySuggestions.map<PopupMenuItem<String>>((String value) {
                                       return PopupMenuItem(value: value, child: Text(value));
                                     }).toList();
                                   },
                                 )
                               : null,
                         ),
                       ),
                     ),
                   ),
                 ],
               ),
             ),
          ]),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Mots de passe
          _buildTextField("Mot de passe (min 6 car.)", _passwordController,
              isPassword: true),
          _buildTextField("Confirmation mot de passe",
              _confirmPasswordController, isPassword: true, validator: (val) {
            if (val != _passwordController.text) {
              return "Les mots de passe ne correspondent pas.";
            }
            return null;
          }),

          const SizedBox(height: 24),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D9DF2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("Créer mon compte et accéder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/welcome'),
            child: const Text(
              "Déjà un compte ? Se connecter",
              style: TextStyle(
                color: Color(0xFF3D9DF2),
                fontWeight: FontWeight.w600,
                fontSize: 15,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {
    bool isPassword = false, 
    TextInputType? keyboardType, 
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator ?? (value) {
          if (value == null || value.trim().isEmpty) return "Ce champ est requis";
          if (isPassword && value.length < 6) return "Min 6 caractères";
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ) : null,
        ),
      ),
    );
  }
}
