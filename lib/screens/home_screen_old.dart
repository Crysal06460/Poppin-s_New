import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poppins_app/screens/child_profile_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_service.dart';
import '../utils/session_util.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String structureName = "Chargement...";
  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> upcomingBirthdays = [];
  List<Map<String, dynamic>> todayAgendaEntries = [];
  bool isLoading = true;
  bool hasChildren = false;

  // Variable pour stocker le type de structure
  String structureType = "AssistanteMaternelle"; // Valeur par défaut

  // Variables pour identifier le membre actuel
  String currentUserEmail = "";
  Set<String> _delegatedChildIds = <String>{};
  Set<String> _myAssignedChildIds = <String>{};

  // Définition des thèmes de couleurs (défaut appliqué immédiatement pour éviter les accès tardifs)
  Color primaryColor = const Color(0xFF3D9DF2);
  Color secondaryColor = const Color(0xFFDFE9F2);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting().then((_) => _fetchData());
  }

  bool _hasShownBirthdayAlert = false;
  bool _hasShownAgendaAlert = false;
  static const String _birthdayAlertShownKey = 'birthday_alert_shown_date';
  static const String _agendaAlertShownKey = 'agenda_alert_shown_date';
  static const Color primaryRed = Color(0xFFD94350); // #D94350

  int _todayAgendaCount = 0;

  // Méthode pour définir les couleurs en fonction du type de structure
  void _setThemeColors() {
    // Utilisation des couleurs de la palette (identique pour tous les types)
    primaryColor = const Color(0xFF3D9DF2); // Bleu #3D9DF2
    secondaryColor = const Color(0xFFDFE9F2); // Bleu clair #DFE9F2
  }

  bool _canCurrentUserEditChild(Map<String, dynamic> child) {
    if (structureType != 'mam') {
      return true;
    }

    final String childId = (child['id'] ?? '').toString();
    if (childId.isEmpty) {
      return false;
    }

    if (_myAssignedChildIds.contains(childId)) {
      return true;
    }

    if (_delegatedChildIds.contains(childId)) {
      return true;
    }

    return false;
  }

  void _showChildReadOnlyMessage() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Cet enfant n'est pas rattaché à votre profil.",
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _handleChildTap(Map<String, dynamic> child) async {
    final String childId = (child['id'] ?? '').toString();
    if (childId.isEmpty) {
      return;
    }

    final bool canEdit = _canCurrentUserEditChild(child);
    print(
        '🔐 TAP enfant $childId (structureType=$structureType) canEdit=$canEdit');
    if (!canEdit) {
      _showChildReadOnlyMessage();
      return;
    }

    final String structId = await _getStructureId();
    if (!mounted || structId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildProfileDetailsScreen(
          childId: childId,
          structureId: structId,
          allowEditing: canEdit,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Afficher une boîte de dialogue de confirmation
      bool confirm = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Déconnexion"),
                content: Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      "ANNULER",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      "OUI",
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirm) return;

      // Supprimer les informations de session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastSessionTime');

      // Déconnexion Firebase
      await SessionUtil.signOut();

      // Redirection vers l'écran de connexion
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print("Erreur lors de la déconnexion: $e");

      // Afficher un message d'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la déconnexion"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("🚨 Aucun utilisateur connecté !");
      context.go('/login');
      return;
    }

    try {
      print(
          "🔍 Vérification des données Firebase pour l'utilisateur: ${user.uid}");

      // Obtenir l'email de l'utilisateur actuel (important pour filtrer les enfants)
      currentUserEmail = user.email?.toLowerCase() ?? '';
      print("👤 Email de l'utilisateur connecté: $currentUserEmail");

      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      // Variable pour stocker l'ID de la structure à utiliser
      String structureDocId =
          user.uid; // Par défaut, utiliser l'ID de l'utilisateur

      // Vérifier si l'utilisateur est un membre MAM
      bool isMamMember = false;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final String role =
            (userData['role'] ?? '').toString().toLowerCase().trim();
        final String linkedStructureId =
            (userData['structureId'] ?? '').toString().trim();

        if (role == 'mamMember'.toLowerCase() && linkedStructureId.isNotEmpty) {
          // C'est un membre MAM, utiliser structureId au lieu de l'ID utilisateur
          structureDocId = linkedStructureId;
          isMamMember = true;
          print(
              "👤 Utilisateur identifié comme membre MAM pour la structure: $structureDocId");
        } else if (linkedStructureId.isNotEmpty &&
            (role == 'assistantfromparent' || role == 'assistant')) {
          // Invitation assistante par un parent : utiliser la structure du parent employeur
          structureDocId = linkedStructureId;
          print(
              "👩‍⚕️ Utilisateur assistante lié à la structure: $structureDocId");
        }
      }

      // Récupérer les données de la structure avec l'ID approprié
      DocumentSnapshot structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureDocId)
          .get();

      if (!structureDoc.exists) {
        print(
            "⚠️ Structure introuvable ! Redirection vers la page de création de structure");
        setState(() {
          isLoading = false;
        });
        context.go('/create-structure');
        return;
      }

      final Map<String, dynamic> structureData =
          (structureDoc.data() as Map<String, dynamic>?) ?? const {};

      String fetchedStructureName = (structureData['structureName'] ??
              structureData['ownerFirstName'] ??
              'Ma Structure')
          .toString()
          .trim();
      if (fetchedStructureName.isEmpty) {
        fetchedStructureName = 'Ma Structure';
      }

      // Récupération du type de structure existant
      String fetchedStructureType =
          (structureData['structureType'] ?? 'AssistanteMaternelle').toString();
      final dynamic showAllField = structureData['showAllChildrenOnHome'];
      bool showAllChildrenOnHome = true;
      if (showAllField is bool) {
        showAllChildrenOnHome = showAllField;
      } else {
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureDocId)
            .set({'showAllChildrenOnHome': true}, SetOptions(merge: true));
      }

      if (!structureData.containsKey('structureType')) {
        // Ajouter le champ s'il n'existe pas encore pour éviter les accès directs nullables
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureDocId)
            .update({'structureType': fetchedStructureType});
      }

      fetchedStructureType = fetchedStructureType.trim().toLowerCase();
      final bool isMamStructure = fetchedStructureType == 'mam';

      // Récupérer les enfants de la structure
      QuerySnapshot childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureDocId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = childrenSnapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();

      // NOUVEAU: Filtrer les enfants selon le type de structure et le rôle de l'utilisateur
      List<Map<String, dynamic>> filteredChildren = [];
      final Set<String> myAssignedChildIds = <String>{};

      Set<String> delegatedTodayChildIds = <String>{};
      String? myMemberId;
      if (isMamStructure) {
        if (showAllChildrenOnHome) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
              "👨‍👧‍👦 Membre MAM: affichage de tous les enfants (mode structure)");
        } else {
          // Tous les membres ne voient que leurs enfants assignés
          filteredChildren = allChildren.where((child) {
            // Vérifier si l'enfant est assigné à ce membre
            String assignedEmail =
                child['assignedMemberEmail']?.toString().trim().toLowerCase() ??
                    '';
            bool isAssigned = assignedEmail == currentUserEmail;

            print(
                "🔍 DEBUG - Enfant: ${child['firstName']}, assignedEmail: '$assignedEmail', currentUserEmail: '$currentUserEmail', isAssigned: $isAssigned");

            // Comparaison stricte, et on s'assure que les deux emails sont en minuscules
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Membre MAM: affichage de ${filteredChildren.length} enfant(s) assigné(s)");
        }

        for (final child in allChildren) {
          final String childId = (child['id'] ?? '').toString();
          if (childId.isEmpty) continue;
          final String assignedEmail =
              child['assignedMemberEmail']?.toString().trim().toLowerCase() ??
                  '';
          if (assignedEmail == currentUserEmail) {
            myAssignedChildIds.add(childId);
          }
        }

        // ⛱️ Overlay délégation du jour: ajouter les enfants que j'accueille par délégation aujourd'hui
        try {
          // Trouver mon memberId via l'email
          final membersSnap = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureDocId)
              .collection('members')
              .where('email', isEqualTo: currentUserEmail)
              .limit(1)
              .get();
          if (membersSnap.docs.isNotEmpty) {
            myMemberId = membersSnap.docs.first.id;
            final todayStart = DateTime.now();
            final start =
                DateTime(todayStart.year, todayStart.month, todayStart.day);
            final end = start.add(const Duration(days: 1));
            final delSnap = await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureDocId)
                .collection('delegations')
                .where('status', isEqualTo: 'accepted')
                .where('amDelegateId', isEqualTo: myMemberId)
                .where('date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThan: Timestamp.fromDate(end))
                .get();
            delegatedTodayChildIds = delSnap.docs
                .map((d) => (d.data()['childId'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet();

            if (delegatedTodayChildIds.isNotEmpty) {
              final already =
                  filteredChildren.map((c) => c['id'] as String).toSet();
              final toAddIds = delegatedTodayChildIds.difference(already);
              if (toAddIds.isNotEmpty) {
                final add = allChildren
                    .where((c) => toAddIds.contains(c['id'] as String));
                filteredChildren.addAll(add);
                print(
                    '➕ Délégations du jour ajoutées au Home: ${toAddIds.length} enfant(s)');
              }
            }
          }
        } catch (e) {
          print('⚠️ Erreur overlay délégations Home: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Assistante Maternelle individuelle: affichage de tous les enfants");
        for (final child in allChildren) {
          final String childId = (child['id'] ?? '').toString();
          if (childId.isNotEmpty) {
            myAssignedChildIds.add(childId);
          }
        }
      }

      // Remplacer les logs de diagnostic pour ne plus mentionner le fondateur
      if (isMamStructure) {
        print(
            "🔍 DIAGNOSTIC - Type de structure: MAM, Utilisateur: $currentUserEmail");
        print(
            "🔍 DIAGNOSTIC - Nombre total d'enfants dans la structure: ${allChildren.length}");
        print(
            "🔍 DIAGNOSTIC - Mode affichage tous les enfants: $showAllChildrenOnHome");
        print(
            "🔍 DIAGNOSTIC - Nombre d'enfants filtrés pour cet utilisateur: ${filteredChildren.length}");

        print("🔍 LISTE DÉTAILLÉE DES ENFANTS:");
        for (var child in allChildren) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().trim().toLowerCase() ??
                  'NON ASSIGNÉ';
          bool isVisible = assignedEmail == currentUserEmail;
          print(
              "  👶 ID: ${child['id']}, Nom: ${child['firstName']}, assignedMemberEmail: '$assignedEmail', Visible pour l'utilisateur: ${isVisible ? 'OUI' : 'NON'}");
        }
      }

      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // Filtrer les enfants pour aujourd'hui (conservant le filtre par membre)
      // et inclure systématiquement ceux arrivés via délégation aujourd'hui
      final List<Map<String, dynamic>> todayChildren = [];
      final Set<String> todayChildIds = {};
      final filteredBySchedule = filteredChildren.where((child) =>
          child['schedule'] != null &&
          child['schedule'].containsKey(capitalizedWeekday));
      for (final child in filteredBySchedule) {
        final id = (child['id'] ?? '').toString();
        if (id.isEmpty) continue;
        if (todayChildIds.add(id)) {
          todayChildren.add(child);
        }
      }
      if (delegatedTodayChildIds.isNotEmpty) {
        final add = filteredChildren.where((c) {
          final id = (c['id'] ?? '').toString();
          return id.isNotEmpty &&
              delegatedTodayChildIds.contains(id) &&
              todayChildIds.add(id);
        });
        todayChildren.addAll(add);
      }

      print(
          "📅 ENFANTS DU JOUR - Mode tous les enfants: $showAllChildrenOnHome, total: ${todayChildren.length}");

      setState(() {
        structureName = fetchedStructureName;
        structureType = fetchedStructureType;
        children = todayChildren;
        // Vérifier si le membre a des enfants qui lui sont assignés
        hasChildren = filteredChildren.isNotEmpty;
        isLoading = false;
        _delegatedChildIds = delegatedTodayChildIds;
        _myAssignedChildIds = myAssignedChildIds;
      });

      // Définir les couleurs après avoir récupéré le type de structure
      _setThemeColors();

      // Trouver les anniversaires à venir (uniquement parmi les enfants filtrés)
      _findUpcomingBirthdays(filteredChildren);

      // Vérifier les rappels d'agenda du jour
      _loadTodayAgendaReminders(structureDocId, currentUserEmail);

      // NOUVELLE LOGIQUE HIÉRARCHIQUE POUR LES POPUPS
      bool shouldShowPopup = false;
      String popupType = "";
      bool forceWelcome = false;

      final prefs = await SharedPreferences.getInstance();
      final String welcomePopupKey =
          'welcome_steps_popup_shown_${structureDocId}';
      final bool welcomePopupAlreadyShown =
          prefs.getBool(welcomePopupKey) ?? false;

      if (isMamStructure) {
        // Pour les MAM: vérifier d'abord s'il y a assez de membres
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureDocId)
            .collection('members')
            .get();

        // Compter le nombre de membres
        final int memberCount = membersSnapshot.docs.length;
        forceWelcome = forceWelcome || ((memberCount <= 1) && !hasChildren);

        print(
            "🔍 DEBUG: Nombre de membres trouvés dans la collection: $memberCount");

        final String mamMembersPopupKey =
            'mam_members_popup_shown_${structureDocId}';
        final bool mamMembersPopupAlreadyShown =
            prefs.getBool(mamMembersPopupKey) ?? false;

        print(
            "🔍 DEBUG: Popup membres déjà affiché? $mamMembersPopupAlreadyShown");

        if (memberCount == 1 && !mamMembersPopupAlreadyShown) {
          // PRIORITÉ 1 : Premier lancement avec un seul membre, afficher le popup UNE FOIS
          shouldShowPopup = true;
          popupType = "addMAMMembers";
          print(
              "⚠️ Premier lancement MAM avec 1 seul membre, affichage du popup...");

          // Marquer le popup comme affiché pour ne plus jamais le montrer
          await prefs.setBool(mamMembersPopupKey, true);
        } else if (!hasChildren) {
          // PRIORITÉ 2 : S'il y a des membres mais pas d'enfants, ajouter des enfants
          shouldShowPopup = true;
          popupType = "addChild";
          print(
              "⚠️ MAM avec membre(s) mais aucun enfant trouvé, affichage du popup...");
        } else {
          print(
              "✅ MAM avec $memberCount membre(s) - popup membres ${mamMembersPopupAlreadyShown ? 'déjà affiché' : 'pas nécessaire'}");
        }
      } else {
        // Pour les assistantes maternelles individuelles : vérifier uniquement les enfants
        if (!hasChildren) {
          shouldShowPopup = true;
          popupType = "addChild";
          print("⚠️ Assistante maternelle sans enfant, affichage du popup...");
        }
        forceWelcome = forceWelcome || !hasChildren;
      }

      if (shouldShowPopup || !welcomePopupAlreadyShown || forceWelcome) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showFirstLaunchGuidance(
            isMamStructure: isMamStructure,
            structureId: structureDocId,
            popupType: shouldShowPopup ? popupType : "",
            forceWelcome: forceWelcome,
          );
        });
      }
    } catch (e) {
      print("🚨 Erreur Firebase : $e");
      setState(() {
        isLoading = false;
        structureName = "Erreur de chargement des données";
      });
      // Définir les couleurs par défaut en cas d'erreur
      _setThemeColors();
    }
  }

  Future<void> _showFirstLaunchGuidance({
    required bool isMamStructure,
    required String structureId,
    required String popupType,
    required bool forceWelcome,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String welcomePopupKey = 'welcome_steps_popup_shown_${structureId}';
    final bool welcomeAlreadyShown = prefs.getBool(welcomePopupKey) ?? false;

    if (forceWelcome || !welcomeAlreadyShown) {
      await _showWelcomeStepsPopup(isMamStructure: isMamStructure);
      await prefs.setBool(welcomePopupKey, true);
    }

    if (!mounted) {
      return;
    }

    if (popupType == "addMAMMembers") {
      _showAddMAMMembersPopup();
    } else if (popupType == "addChild") {
      _showAddChildPopup();
    }
  }

  Future<void> _showWelcomeStepsPopup({required bool isMamStructure}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  // Gradient décoratif
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(0.3),
                            primaryColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.fromLTRB(32, 40, 32, 24),
                        child: Column(
                          children: [
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, double value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          primaryColor,
                                          primaryColor.withOpacity(0.7)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.home_rounded,
                                        size: 36, color: Colors.white),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 24),
                            Text('Bienvenue sur',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5)),
                            SizedBox(height: 4),
                            Text('Poppin\'s',
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2C3E50),
                                    letterSpacing: -0.5)),
                          ],
                        ),
                      ),

                      // Contenu scrollable
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Les prochaines étapes',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50))),
                              SizedBox(height: 24),
                              if (isMamStructure)
                                _buildModernStepItem(
                                  icon: Icons.person_add_rounded,
                                  iconColor: primaryColor,
                                  title: 'Ajoutez un membre de votre MAM',
                                  description:
                                      "Saisissez son email, son prénom et son nom. Il recevra un email d'invitation : il téléchargera l'application sur App Store ou Google Play, choisira \"J'ai un code d'invitation\", saisira son email et rejoindra la MAM. Vous pourrez ajouter ou retirer des membres depuis Dashboard -> Administration.",
                                ),
                              if (isMamStructure) SizedBox(height: 20),
                              _buildModernStepItem(
                                icon: Icons.child_care_rounded,
                                iconColor: primaryColor.withOpacity(0.8),
                                title: 'Ajoutez un enfant',
                                description:
                                    "Préparez sa date de naissance, l'email des parents, ses horaires de présence, etc. À la fin, les parents reçoivent un email d'invitation : ils téléchargent l'application, choisissent \"J'ai un code d'invitation\", saisissent leur email et accèdent au fil de leur enfant. Vous pouvez gérer ces invitations depuis Dashboard -> Enfants & parents.",
                              ),
                              SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),

                      // Bouton
                      Padding(
                        padding: EdgeInsets.fromLTRB(32, 16, 32, 32),
                        child: _buildModernContinueButton(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernStepItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),

            SizedBox(width: 16),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernContinueButton() {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continuer',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

// Nouvelle méthode pour afficher le popup d'ajout de membres MAM
  void _showAddMAMMembersPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Ajouter les membres de la MAM ?",
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Icone_Ajout_Enfant.png', height: 100),
              // Remplacer par une image appropriée
              const SizedBox(height: 10),
              const Text(
                "Aucun membre n'est encore enregistré pour cette MAM. Voulez-vous les ajouter maintenant ?",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("NON",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToAddMAMMembers();
              },
              child: Text("OUI",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddMAMMembers() {
    context.go('/add-mam-members');
  }

  // Remplacez la méthode _findUpcomingBirthdays dans home_screen.dart

  // Remplacez la méthode _findUpcomingBirthdays dans home_screen.dart

  void _findUpcomingBirthdays(List<Map<String, dynamic>> allChildren) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

    print("🎂 DEBUG: Date d'aujourd'hui: $todayFormatted");
    print("🎂 DEBUG: Nombre d'enfants à vérifier: ${allChildren.length}");

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final lastShownDate = prefs.getString(_birthdayAlertShownKey) ?? '';

    final bool alreadyShownToday = lastShownDate == todayFormatted;
    print("🎂 DEBUG: Popup déjà affiché aujourd'hui? $alreadyShownToday");

    List<Map<String, dynamic>> birthdayChildren = [];
    List<Map<String, dynamic>> todayBirthdayChildren = [];

    for (var child in allChildren) {
      if (child['birthdate'] == null) {
        print("🎂 DEBUG: ${child['firstName']} - pas de date de naissance");
        continue;
      }

      try {
        final birthdateStr = child['birthdate'];
        print(
            "🎂 DEBUG: ${child['firstName']} - birthdate brut: $birthdateStr");

        DateTime birthdate;

        // Améliorer la gestion du format de date ISO
        if (birthdateStr is String) {
          // Gérer explicitement le format ISO des dates Firebase
          // Format attendu: "2025-06-02T00:00:00.000" ou "2025-06-02"
          String dateOnly = birthdateStr.split('T')[0];
          print("🎂 DEBUG: ${child['firstName']} - date extraite: $dateOnly");
          birthdate = DateTime.parse(dateOnly);
        } else {
          print(
              "⚠️ Format de date non reconnu pour ${child['firstName']}: $birthdateStr");
          continue;
        }

        print(
            "🎂 DEBUG: ${child['firstName']} - date de naissance parsée: ${DateFormat('yyyy-MM-dd').format(birthdate)}");

        // Vérifier si c'est aujourd'hui (même jour et même mois)
        bool isToday =
            today.day == birthdate.day && today.month == birthdate.month;

        print(
            "🎂 DEBUG: ${child['firstName']} - aujourd'hui: ${today.day}/${today.month}, naissance: ${birthdate.day}/${birthdate.month}, c'est aujourd'hui? $isToday");

        if (isToday) {
          print(
              "🎉 C'EST L'ANNIVERSAIRE DE ${child['firstName']} AUJOURD'HUI!");
          todayBirthdayChildren.add({
            ...child,
            'daysUntilBirthday': 0,
          });
          continue;
        }

        // Calculer le prochain anniversaire cette année
        DateTime nextBirthday = DateTime(
          today.year,
          birthdate.month,
          birthdate.day,
        );

        // Si la date est déjà passée cette année, passer à l'année suivante
        if (nextBirthday.isBefore(today)) {
          nextBirthday = DateTime(
            today.year + 1,
            birthdate.month,
            birthdate.day,
          );
        }

        // Calculer les jours exacts entre aujourd'hui et l'anniversaire
        int daysUntilBirthday = nextBirthday.difference(today).inDays;

        print(
            "⏱️ Jours restants jusqu'à l'anniversaire de ${child['firstName']}: $daysUntilBirthday");

        // Si l'anniversaire est dans les 10 prochains jours
        if (daysUntilBirthday <= 10) {
          birthdayChildren.add({
            ...child,
            'daysUntilBirthday': daysUntilBirthday,
            'nextBirthday': nextBirthday,
          });
        }
      } catch (e) {
        print(
            "🚨 Erreur lors du traitement de l'anniversaire de ${child['firstName']}: $e");
      }
    }

    // Trier par nombre de jours restants
    birthdayChildren.sort(
        (a, b) => a['daysUntilBirthday'].compareTo(b['daysUntilBirthday']));

    print("📋 Nombre d'anniversaires à venir: ${birthdayChildren.length}");
    print(
        "🎂 Nombre d'anniversaires aujourd'hui: ${todayBirthdayChildren.length}");

    setState(() {
      upcomingBirthdays = birthdayChildren;
    });

    // Afficher le popup UNIQUEMENT si :
    // 1. Il y a des anniversaires aujourd'hui
    // 2. Le popup n'a pas déjà été affiché aujourd'hui
    // 3. Le flag de session n'est pas encore défini
    if (todayBirthdayChildren.isNotEmpty &&
        !alreadyShownToday &&
        !_hasShownBirthdayAlert) {
      print(
          "🎉 ANNIVERSAIRE DÉTECTÉ - Affichage du popup (première fois aujourd'hui)!");

      // Marquer comme affiché pour cette session
      _hasShownBirthdayAlert = true;

      // Enregistrer la date pour éviter les répétitions aujourd'hui
      prefs.setString(_birthdayAlertShownKey, todayFormatted);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBirthdayAlert(todayBirthdayChildren);
      });
    } else {
      if (todayBirthdayChildren.isNotEmpty && alreadyShownToday) {
        print("🔕 Anniversaire aujourd'hui mais popup déjà affiché");
      } else if (todayBirthdayChildren.isNotEmpty && _hasShownBirthdayAlert) {
        print(
            "🔕 Anniversaire aujourd'hui mais popup déjà affiché cette session");
      } else {
        print("🔍 Aucun anniversaire aujourd'hui détecté");
      }
    }
  }

  void _showBirthdayAlert(List<Map<String, dynamic>> birthdayChildren) {
    // Obtenir les dimensions de l'écran pour des calculs relatifs
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.08, // 8% de marge horizontale
            vertical: screenSize.height * 0.05, // 5% de marge verticale
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(screenSize.width * 0.05), // 5% de l'écran
          ),
          child: Container(
            width: screenSize.width * 0.9, // 90% de la largeur de l'écran
            constraints: BoxConstraints(
              maxWidth: 450, // Limite maximale pour les grands écrans
              maxHeight:
                  screenSize.height * 0.7, // Ne pas dépasser 70% de la hauteur
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre de l'anniversaire avec gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: screenSize.height * 0.02, // 2% de la hauteur
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF2B705), // Jaune #F2B705
                        const Color(0xFFD94350), // Rouge #D94350
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(screenSize.width * 0.05),
                      topRight: Radius.circular(screenSize.width * 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cake,
                          color: Colors.white, size: screenSize.width * 0.06),
                      SizedBox(width: screenSize.width * 0.02),
                      Flexible(
                        child: Text(
                          "🎉 Anniversaire du jour ! 🎉",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: screenSize.width *
                                0.045, // Taille relative à l'écran
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu avec image et texte
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(screenSize.width * 0.05),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Image d'un gâteau d'anniversaire
                          Container(
                            height: screenSize.height *
                                0.15, // 15% de la hauteur de l'écran
                            child: Image.asset(
                              'assets/images/gateau-danniversaire.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.cake,
                                      size: screenSize.width * 0.2,
                                      color: Colors.orange),
                            ),
                          ),

                          SizedBox(height: screenSize.height * 0.02),

                          // Liste des enfants dont c'est l'anniversaire
                          ...birthdayChildren
                              .map((child) => Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: screenSize.height * 0.01),
                                    child: Text(
                                      "C'est l'anniversaire de ${child['firstName']} aujourd'hui !",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: screenSize.width *
                                            0.04, // 4% de la largeur de l'écran
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),

                          SizedBox(height: screenSize.height * 0.015),

                          // Message de rappel
                        ],
                      ),
                    ),
                  ),
                ),

                // Bouton fermer avec animation
                Container(
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(screenSize.width * 0.05),
                        bottomRight: Radius.circular(screenSize.width * 0.05),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: screenSize.height * 0.02),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            bottomLeft:
                                Radius.circular(screenSize.width * 0.05),
                            bottomRight:
                                Radius.circular(screenSize.width * 0.05),
                          ),
                        ),
                        child: Text(
                          "FERMER",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenSize.width * 0.04,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _loadTodayAgendaReminders(
      String structureDocId, String userEmailLower) async {
    try {
      final String normalizedEmail = userEmailLower.toLowerCase();
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureDocId)
          .collection('agendaEntries')
          .where('dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dueDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final List<Map<String, dynamic>> entries = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        final dueField = data['dueDate'];
        DateTime dueDate;
        if (dueField is Timestamp) {
          dueDate = dueField.toDate();
        } else if (dueField is DateTime) {
          dueDate = dueField;
        } else if (dueField is String) {
          final parsed = DateTime.tryParse(dueField);
          if (parsed == null) continue;
          dueDate = parsed;
        } else {
          continue;
        }

        final List<String> visibilityRaw = [];
        if (data['visibleTo'] is Iterable) {
          for (final item in (data['visibleTo'] as Iterable)) {
            if (item != null) {
              visibilityRaw.add(item.toString().toLowerCase());
            }
          }
        }

        final bool isShared = visibilityRaw.contains('all');
        final bool isVisibleForUser = isShared ||
            (normalizedEmail.isNotEmpty &&
                visibilityRaw.contains(normalizedEmail));

        if (!isVisibleForUser) continue;

        entries.add({
          'id': doc.id,
          'title': (data['title'] ?? 'Rappel').toString(),
          'notes': (data['notes'] ?? '').toString().trim(),
          'dueDate': dueDate,
          'isShared': isShared,
        });
      }

      entries.sort((a, b) {
        final aDate = a['dueDate'] as DateTime;
        final bDate = b['dueDate'] as DateTime;
        return aDate.compareTo(bDate);
      });

      final String todayFormatted = DateFormat('yyyy-MM-dd').format(startOfDay);
      final prefs = await SharedPreferences.getInstance();
      final String lastShownDate = prefs.getString(_agendaAlertShownKey) ?? '';
      final bool alreadyShownToday = lastShownDate == todayFormatted;

      if (!mounted) return;
      setState(() {
        todayAgendaEntries = entries;
        _todayAgendaCount = entries.length;
      });

      if (entries.isNotEmpty && !alreadyShownToday && !_hasShownAgendaAlert) {
        _hasShownAgendaAlert = true;
        await prefs.setString(_agendaAlertShownKey, todayFormatted);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAgendaAlert(entries);
        });
      }
    } catch (e) {
      print('📅 Erreur lors du chargement des rappels agenda: $e');
      if (!mounted) return;
      setState(() {
        todayAgendaEntries = [];
        _todayAgendaCount = 0;
      });
    }
  }

  void _showAgendaAlert(List<Map<String, dynamic>> entries) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final Size screenSize = MediaQuery.of(context).size;
        final bool isTabletDevice = screenSize.shortestSide >= 600;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTabletDevice ? 32 : 20),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTabletDevice ? 80 : 24,
            vertical: isTabletDevice ? 60 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * (isTabletDevice ? 0.6 : 0.7),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isTabletDevice ? 32 : 20),
                      topRight: Radius.circular(isTabletDevice ? 32 : 20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rappels du jour',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTabletDevice ? 24 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Voici ce qu’il ne faut pas oublier aujourd’hui.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isTabletDevice ? 16 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final entry = entries[index];
                      final String title =
                          entry['title'] as String? ?? 'Rappel';
                      final String notes = entry['notes'] as String? ?? '';
                      final bool isShared = entry['isShared'] as bool? ?? false;
                      final DateTime? dueDate = entry['dueDate'] as DateTime?;
                      final String? formattedTime = dueDate != null
                          ? DateFormat('HH:mm', 'fr_FR').format(dueDate)
                          : null;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isShared
                                ? Colors.teal.withOpacity(0.4)
                                : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.event_available,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (formattedTime != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'À $formattedTime',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                notes,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Chip(
                                label: Text(
                                  isShared
                                      ? 'Partagé avec la MAM'
                                      : 'Rappel perso',
                                  style: TextStyle(
                                    color: isShared
                                        ? Colors.teal.shade800
                                        : Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: isShared
                                    ? Colors.teal.shade50
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Compris'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgendaBadge(bool isLarge) {
    final String displayCount =
        _todayAgendaCount > 9 ? '9+' : _todayAgendaCount.toString();
    final double horizontalPadding = isLarge ? 10 : 6;
    final double verticalPadding = isLarge ? 4 : 3;
    final double fontSize = isLarge ? 14 : 10;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2B705),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        displayCount,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildPhoneContent(List<Map<String, dynamic>> features) {
    return Column(
      children: [
        // Section des enfants présents
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre avec icône
                Row(
                  children: [
                    Image.asset(
                      'assets/images/Icone_Enfant_Present.png',
                      width: 60,
                      height: 60,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.people_alt_rounded,
                        color: primaryColor,
                        size: 60,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Enfants présents aujourd'hui",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Grille d'avatars des enfants présents
                children.isEmpty
                    ? Center(
                        child: Text(
                          "Aucun enfant prévu aujourd'hui",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: children
                            .map((child) => _buildChildAvatar(child, false))
                            .toList(),
                      ),

                // Section des anniversaires (version compacte)
                if (upcomingBirthdays.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.cake_rounded,
                        size: 14,
                        color: const Color(0xFFD94350),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Anniversaires: ",
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFFD94350),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          upcomingBirthdays.map((b) {
                            if (b['daysUntilBirthday'] == 0) {
                              return "${b['firstName']} (Aujourd'hui)";
                            } else if (b['daysUntilBirthday'] == 1) {
                              return "${b['firstName']} (Demain)";
                            } else if (b['daysUntilBirthday'] == 2) {
                              return "${b['firstName']} (Après-demain)";
                            } else {
                              return "${b['firstName']} (${b['daysUntilBirthday']}j)";
                            }
                          }).join(", "),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Grille d'icônes des fonctionnalités (iPhone)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) => _buildGridItem(
                context,
                features[index]['route'] as String,
                features[index]['name'] as String,
                features[index]['imagePath'] as String,
                false, // isTablet = false
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletContent(List<Map<String, dynamic>> features) {
    return LayoutBuilder(builder: (context, constraints) {
      // Récupérer la taille disponible de l'écran
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;

      // Calculer des dimensions en pourcentages
      final double sideMargin = maxWidth * 0.03; // 3% de marge sur les côtés
      final double columnGap = maxWidth * 0.025; // Augmenté de 0.02 à 0.025

      return Padding(
        padding: EdgeInsets.fromLTRB(
            sideMargin, maxHeight * 0.02, sideMargin, maxHeight * 0.02),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau latéral gauche (enfants présents + anniversaires) - légèrement augmenté
            Expanded(
              flex: 4, // Augmenté de 3 à 4 pour donner plus d'espace
              child: Container(
                margin: EdgeInsets.only(right: columnGap),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                      maxWidth * 0.025), // Augmenté de 0.02 à 0.025
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre avec icône
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/Icone_Enfant_Present.png',
                            width: maxWidth * 0.07, // Augmenté de 0.06 à 0.07
                            height: maxWidth * 0.07,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.people_alt_rounded,
                              color: primaryColor,
                              size: maxWidth * 0.07,
                            ),
                          ),
                          SizedBox(
                              width:
                                  maxWidth * 0.015), // Augmenté de 0.01 à 0.015
                          Expanded(
                            child: Text(
                              "Enfants présents",
                              style: TextStyle(
                                fontSize: maxWidth *
                                    0.022, // Augmenté de 0.02 à 0.022
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                          height:
                              maxHeight * 0.025), // Augmenté de 0.02 à 0.025

                      // Liste des enfants présents - FORMAT VERTICAL
                      Expanded(
                        child: children.isEmpty
                            ? Center(
                                child: Text(
                                  "Aucun enfant prévu aujourd'hui",
                                  style: TextStyle(
                                    fontSize: maxWidth *
                                        0.018, // Augmenté de 0.016 à 0.018
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            // Liste verticale avec plus d'espacement
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: children.length,
                                // Utiliser separatorBuilder au lieu de padding
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: maxHeight * 0.02),
                                itemBuilder: (context, index) =>
                                    _buildChildAvatarVertical(
                                        children[index], maxWidth, maxHeight),
                              ),
                      ),

                      // Section des anniversaires
                      if (upcomingBirthdays.isNotEmpty) ...[
                        SizedBox(
                            height:
                                maxHeight * 0.025), // Augmenté de 0.02 à 0.025
                        Container(
                          padding: EdgeInsets.all(
                              maxWidth * 0.02), // Augmenté de 0.015 à 0.02
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.orange.shade200, width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.cake_rounded,
                                    size: maxWidth *
                                        0.022, // Augmenté de 0.02 à 0.022
                                    color: const Color(0xFFD94350),
                                  ),
                                  SizedBox(
                                      width: maxWidth *
                                          0.015), // Augmenté de 0.01 à 0.015
                                  Expanded(
                                    child: Text(
                                      "Anniversaires",
                                      style: TextStyle(
                                        fontSize: maxWidth *
                                            0.018, // Augmenté de 0.016 à 0.018
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFD94350),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                  height: maxHeight *
                                      0.015), // Augmenté de 0.01 à 0.015
                              // Limiter la hauteur avec un container à défilement
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: maxHeight *
                                      0.14, // Augmenté de 0.12 à 0.14
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: upcomingBirthdays.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: maxHeight * 0.01),
                                  itemBuilder: (context, index) {
                                    final b = upcomingBirthdays[index];
                                    String message;
                                    if (b['daysUntilBirthday'] == 0) {
                                      message = "Aujourd'hui";
                                    } else if (b['daysUntilBirthday'] == 1) {
                                      message = "Demain";
                                    } else if (b['daysUntilBirthday'] == 2) {
                                      message = "Après-demain";
                                    } else {
                                      message = "${b['daysUntilBirthday']}j";
                                    }

                                    return Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "• ${b['firstName']}",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: maxWidth * 0.016,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                            width: maxWidth *
                                                0.01), // Augmenté de 0.005 à 0.01
                                        Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: maxWidth * 0.016,
                                            color: b['daysUntilBirthday'] == 0
                                                ? Colors.orange.shade700
                                                : Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Panneau de droite (fonctionnalités) - légèrement réduit pour compenser
            Expanded(
              flex: 6, // Réduit de 7 à 6 car le panel gauche a été augmenté
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre de la section fonctionnalités
                      Text(
                        "Fonctionnalités",
                        style: TextStyle(
                          fontSize: maxWidth * 0.022,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.01),

                      // Grille de fonctionnalités réactive
                      Expanded(
                        child: _buildResponsiveFeaturesGrid(
                            features, maxWidth, maxHeight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildChildAvatarVertical(
      Map<String, dynamic> child, double maxWidth, double maxHeight) {
    final isBoy = child['gender'] == 'Garçon';
    final displayName = child['firstName'] ?? 'Enfant';
    final photoUrl = child['photoUrl'];
    final childId = child['id'];

    // Tailles proportionnelles pour l'affichage vertical - AUGMENTÉES
    final double avatarSize =
        maxWidth * 0.08; // Augmenté de 5% à 8% de la largeur
    final double fontSize = maxWidth * 0.018; // Augmenté de 0.014 à 0.018

    return GestureDetector(
      onTap: () => _handleChildTap(child),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical:
                maxHeight * 0.01), // Augmentation de l'espacement vertical
        child: Row(
          children: [
            // Avatar de l'enfant avec badge
            Stack(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isBoy
                          ? [primaryColor.withOpacity(0.7), primaryColor]
                          : [Colors.pink.withOpacity(0.7), Colors.pink],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isBoy ? primaryColor : Colors.pink)
                            .withOpacity(0.3),
                        blurRadius: 6, // Augmenté de 4 à 6
                        offset: const Offset(0, 3), // Augmenté de 2 à 3
                      ),
                    ],
                  ),
                  child: Center(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              width: avatarSize * 0.9,
                              height: avatarSize * 0.9,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackAvatarSimple(
                                displayName,
                                avatarSize * 0.9,
                                avatarSize * 0.4,
                              ),
                            ),
                          )
                        : _buildFallbackAvatarSimple(
                            displayName,
                            avatarSize * 0.9,
                            avatarSize * 0.4,
                          ),
                  ),
                ),

                // Badge de notification pour messages non lus
              ],
            ),
            SizedBox(width: maxWidth * 0.03), // Augmenté de 0.02 à 0.03
            // Nom de l'enfant
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Version simplifiée pour le layout vertical
  Widget _buildFallbackAvatarSimple(String name, double size, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

// Version adaptée pour afficher 3x4 fonctionnalités avec des icônes plus grandes
  Widget _buildResponsiveFeaturesGrid(
      List<Map<String, dynamic>> features, double maxWidth, double maxHeight) {
    // Diviser les fonctionnalités en 3 rangées
    final List<List<Map<String, dynamic>>> rows = [
      features.sublist(0, 4), // Première rangée: 0-3
      features.sublist(4, 8), // Deuxième rangée: 4-7
      features.sublist(8, 12), // Troisième rangée: 8-11
    ];

    return Column(
      children: [
        // Distribution verticale uniforme
        Expanded(child: SizedBox()), // Espace flexible 1

        // Première rangée
        Container(
          height: maxHeight * 0.16, // Augmenté de 14% à 16%
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows[0]
                .map((feature) => Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: maxWidth * 0.01),
                        child: _buildTabletGridItem(
                          context,
                          feature['route'] as String,
                          feature['name'] as String,
                          feature['imagePath'] as String,
                          maxWidth,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        Expanded(child: SizedBox()), // Espace flexible 2

        // Deuxième rangée
        Container(
          height: maxHeight * 0.16, // Augmenté de 14% à 16%
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows[1]
                .map((feature) => Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: maxWidth * 0.01),
                        child: _buildTabletGridItem(
                          context,
                          feature['route'] as String,
                          feature['name'] as String,
                          feature['imagePath'] as String,
                          maxWidth,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        Expanded(child: SizedBox()), // Espace flexible 3

        // Troisième rangée
        Container(
          height: maxHeight * 0.16, // Augmenté de 14% à 16%
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rows[2]
                .map((feature) => Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: maxWidth * 0.01),
                        child: _buildTabletGridItem(
                          context,
                          feature['route'] as String,
                          feature['name'] as String,
                          feature['imagePath'] as String,
                          maxWidth,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        Expanded(child: SizedBox()), // Espace flexible 4
      ],
    );
  }

// Méthode améliorée pour les éléments de grille sur iPad avec dimensions relatives
  // Méthode améliorée pour les éléments de grille sur iPad avec dimensions relatives
  // Dans home_screen.dart, remplacez ENTIÈREMENT cette méthode _buildTabletGridItem :

  Widget _buildTabletGridItem(BuildContext context, String route, String name,
      String imagePath, double maxWidth) {
    // Augmentation de la taille des icônes
    final bool isAgendaIcon = route == '/agenda';
    final double baseSize = maxWidth * 0.08; // Augmenté de 6% à 8%
    final double imageSize = isAgendaIcon ? baseSize * 0.85 : baseSize;

    // Vérifier si c'est l'icône des échanges pour ajouter le badge de notification
    final bool isExchangeIcon = route == '/exchanges';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image centrée
            Expanded(
              flex: 3, // Proportions pour l'image
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Image de l'icône
                  Image.asset(
                    imagePath,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_not_supported,
                      size: imageSize,
                      color: primaryColor,
                    ),
                  ),

                  // Badge de notification pour les échanges - CORRIGÉ
                  if (isExchangeIcon)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: FutureBuilder<List<String>>(
                        future: _getAssignedChildrenIds(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return SizedBox.shrink();
                          }

                          final List<String> assignedChildIds = snapshot.data!;

                          return StreamBuilder<QuerySnapshot>(
                            // 🔥 CORRECTION CRITIQUE : Écouter les messages des PARENTS 🔥
                            stream: FirebaseFirestore.instance
                                .collection('exchanges')
                                .where('childId', whereIn: assignedChildIds)
                                .where('nonLu', isEqualTo: true)
                                .where('senderType',
                                    isEqualTo: 'parent') // ← AJOUTÉ !
                                .snapshots(),
                            builder: (context, snapshot) {
                              final int nonLuCount =
                                  snapshot.data?.docs.length ?? 0;
                              print(
                                  "🔔 Badge Home Tablet - Messages non lus des PARENTS: $nonLuCount");

                              if (nonLuCount > 0) {
                                return Container(
                                  padding: EdgeInsets.all(maxWidth * 0.01),
                                  decoration: BoxDecoration(
                                    color: primaryRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    nonLuCount.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: maxWidth * 0.016,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              } else {
                                return SizedBox.shrink();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  if (isAgendaIcon && _todayAgendaCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildAgendaBadge(true),
                    ),
                ],
              ),
            ),

            // Texte centré en dessous
            Expanded(
              flex: 1, // Proportions pour le texte
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: maxWidth * 0.016, // Augmenté légèrement
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _getAssignedChildrenIds() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ DEBUG: Utilisateur non connecté");
        return [];
      }

      final currentUserEmail = user.email?.toLowerCase() ?? '';
      print("🔍 DEBUG: Email utilisateur connecté: $currentUserEmail");
      print("🔍 DEBUG: UID utilisateur: ${user.uid}");

      // Vérifier si le document utilisateur existe
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (!userDoc.exists) {
        print("⚠️ DEBUG: Document utilisateur non trouvé, essai par UID...");

        // Recherche par UID dans les données
        final queryByUid = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (queryByUid.docs.isNotEmpty) {
          userDoc = queryByUid.docs.first;
          print("✅ DEBUG: Document utilisateur trouvé par UID: ${userDoc.id}");
        } else {
          print(
              "🔧 DEBUG: Aucun document trouvé, DÉTECTION AUTOMATIQUE du type d'utilisateur...");

          // 🔥 DÉTECTION AUTOMATIQUE DU TYPE D'UTILISATEUR 🔥

          // 1. Vérifier si c'est le propriétaire d'une structure
          final structureQuery = await FirebaseFirestore.instance
              .collection('structures')
              .where('email', isEqualTo: currentUserEmail)
              .get();

          String role = 'unknown';
          String structureId = user.uid;
          String firstName =
              user.displayName?.split(' ').first ?? 'Utilisateur';
          String lastName = user.displayName?.split(' ').last ?? '';

          if (structureQuery.docs.isNotEmpty) {
            // C'est le propriétaire d'une structure
            final structureData = structureQuery.docs.first.data();
            final structureType =
                structureData['structureType'] ?? 'AssistanteMaternelle';

            if (structureType == 'MAM') {
              role = 'mamFounder'; // Fondateur MAM
            } else {
              role =
                  'assistanteMaternelle'; // Assistante maternelle individuelle
            }

            structureId = structureQuery.docs.first.id;
            firstName = structureData['firstName'] ?? firstName;
            lastName = structureData['lastName'] ?? lastName;

            print("✅ DEBUG: Détecté comme propriétaire de structure ($role)");
          } else {
            // 2. Vérifier si c'est un membre MAM
            final mamMemberQuery = await FirebaseFirestore.instance
                .collectionGroup('members')
                .where('email', isEqualTo: currentUserEmail)
                .get();

            if (mamMemberQuery.docs.isNotEmpty) {
              role = 'mamMember';
              final memberData = mamMemberQuery.docs.first.data();
              structureId =
                  mamMemberQuery.docs.first.reference.parent.parent!.id;
              firstName = memberData['firstName'] ?? firstName;
              lastName = memberData['lastName'] ?? lastName;

              print("✅ DEBUG: Détecté comme membre MAM");
            } else {
              // 3. Vérifier si c'est un parent
              final parentQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: currentUserEmail)
                  .where('role', isEqualTo: 'parent')
                  .get();

              if (parentQuery.docs.isEmpty) {
                // Rechercher dans toutes les collections users par children array
                final allUsersQuery =
                    await FirebaseFirestore.instance.collection('users').get();

                for (var doc in allUsersQuery.docs) {
                  final data = doc.data();
                  if (data['email']?.toString().toLowerCase() ==
                          currentUserEmail ||
                      doc.id.toLowerCase() == currentUserEmail) {
                    role = data['role'] ?? 'parent';
                    structureId = data['structureId'] ?? structureId;
                    firstName = data['firstName'] ?? firstName;
                    lastName = data['lastName'] ?? lastName;
                    break;
                  }
                }

                if (role == 'unknown') {
                  role = 'parent'; // Par défaut
                  print(
                      "⚠️ DEBUG: Type non détecté, défini comme parent par défaut");
                }
              }
            }
          }

          print(
              "🔧 DEBUG: Création du document avec role=$role, structureId=$structureId");

          // Créer le document utilisateur avec les données détectées
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserEmail)
              .set({
            'uid': user.uid,
            'email': currentUserEmail,
            'role': role,
            'structureId': structureId,
            'firstName': firstName,
            'lastName': lastName,
            'unreadMessages': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });

          print("✅ DEBUG: Document utilisateur créé avec succès!");

          // Récupérer le document nouvellement créé
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserEmail)
              .get();
        }
      } else {
        print("✅ DEBUG: Document utilisateur trouvé par email");
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final bool isMamMember = userData['role'] == 'mamMember';
      final String structureId = userData['structureId'] ?? user.uid;

      print("🔍 DEBUG: role=${userData['role']}, structureId=$structureId");

      // Si c'est un parent, pas besoin de chercher des enfants assignés
      if (userData['role'] == 'parent') {
        print(
            "👪 DEBUG: Utilisateur parent - pas de notification badge côté assistante");
        return [];
      }

      // Récupérer les enfants (pour assistantes maternelles et membres MAM)
      QuerySnapshot childrenSnapshot;

      bool allowAllChildrenForBadge = true;
      if (isMamMember) {
        try {
          final structureDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .get();
          final data = structureDoc.data();
          if (data != null && data['showAllChildrenOnHome'] is bool) {
            allowAllChildrenForBadge = data['showAllChildrenOnHome'] as bool;
          }
        } catch (e) {
          print(
              "⚠️ DEBUG: Impossible de récupérer showAllChildren pour le badge: $e");
        }
      }

      if (isMamMember) {
        if (allowAllChildrenForBadge) {
          print(
              "🔍 DEBUG: Préférence tous les enfants active - récupération de tous les enfants de la structure");
          childrenSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .get();
        } else {
          print("🔍 DEBUG: Recherche enfants assignés à $currentUserEmail");

          childrenSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .where('assignedMemberEmail', isEqualTo: currentUserEmail)
              .get();
        }
      } else {
        print("🔍 DEBUG: Recherche TOUS les enfants (assistante individuelle)");

        childrenSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .get();
      }

      // Extraire les IDs des enfants
      final List<String> childIds =
          childrenSnapshot.docs.map((doc) => doc.id).toList();

      print("🔍 DEBUG: IDs enfants final: $childIds");

      // TEST DIRECT des messages pour vérification
      if (childIds.isNotEmpty) {
        final testQuery = await FirebaseFirestore.instance
            .collection('exchanges')
            .where('childId', whereIn: childIds)
            .where('nonLu', isEqualTo: true)
            .where('senderType', isEqualTo: 'parent')
            .get();

        print("🔍 DEBUG: Messages non lus trouvés: ${testQuery.docs.length}");
      }

      return childIds;
    } catch (e) {
      print("❌ DEBUG: Erreur: $e");
      return [];
    }
  }

  void _showAddChildPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Ajouter un premier enfant ?",
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Icone_Ajout_Enfant.png', height: 100),
              const SizedBox(height: 10),
              const Text(
                "Aucun enfant n'est encore enregistré. Voulez-vous en ajouter un maintenant ?",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("NON",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/child-info');
              },
              child: Text("OUI",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/exchanges');
    }
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si c'est un membre MAM, obtenir l'ID de la structure associée
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur
    return user.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🆕 AJOUT : Vérification de l'abonnement
    return FutureBuilder<bool>(
      future: SubscriptionService.isUserSubscribed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        final bool isSubscribed = snapshot.data ?? false;

        if (!isSubscribed) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: primaryColor,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Abonnement requis",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Pour accéder à toutes les fonctionnalités",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => context.go('/pricing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: Text(
                      "CHOISIR UN ABONNEMENT",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Le reste du code existant - utilisateur abonné
        _setThemeColors();

        final Size screenSize = MediaQuery.of(context).size;
        final bool isTablet = screenSize.shortestSide >= 600;

        final features = [
          {
            'route': '/horaires',
            'name': 'Horaires',
            'imagePath': 'assets/images/Icone_Horaires.png'
          },
          {
            'route': '/repas',
            'name': 'Repas',
            'imagePath': 'assets/images/Icone_Repas.png'
          },
          {
            'route': '/activites',
            'name': 'Activités',
            'imagePath': 'assets/images/Icone_Activites.png'
          },
          {
            'route': '/sieste',
            'name': 'Sieste',
            'imagePath': 'assets/images/Icone_Siestes.png'
          },
          {
            'route': '/sante',
            'name': 'Santé',
            'imagePath': 'assets/images/Icone_Sante.png'
          },
          {
            'route': '/change',
            'name': 'Change',
            'imagePath': 'assets/images/Icone_Changes.png'
          },
          {
            'route': '/photos',
            'name': 'Photos',
            'imagePath': 'assets/images/Icone_Photos.png'
          },
          {
            'route': '/agenda',
            'name': 'Agenda',
            'imagePath': 'assets/images/Icone_Agenda.png'
          },
          {
            'route': '/stock',
            'name': 'Stock',
            'imagePath': 'assets/images/Icone_Stock.png'
          },
          {
            'route': '/recap-enfant',
            'name': 'Recap',
            'imagePath': 'assets/images/Icone_Recaptitulatif.png'
          },
          {
            'route': '/actualites',
            'name': 'Actualités',
            'imagePath': 'assets/images/Icone_Actualites.png'
          },
          {
            'route': '/transmissions',
            'name': 'Transm.',
            'imagePath': 'assets/images/Icone_Transmission.png'
          },
        ];

        final bool hideStructureName = structureType == 'parent_employeur' ||
            structureType == 'parentemployeur';
        final String displayStructureName =
            hideStructureName ? '' : structureName;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // En-tête avec fond de couleur - hauteur et marges relatives
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(screenSize.width * 0.06),
                    bottomRight: Radius.circular(screenSize.width * 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      screenSize.width *
                          (isTablet ? 0.03 : 0.025), // 3% ou 2.5% de la largeur
                      screenSize.height * 0.02, // 2% de la hauteur
                      screenSize.width * (isTablet ? 0.03 : 0.025),
                      screenSize.height *
                          (isTablet
                              ? 0.02
                              : 0.01), // Plus grand padding bas sur tablette
                    ),
                    child: Column(
                      children: [
                        // Nom de la structure et date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: hideStructureName
                                  ? const SizedBox.shrink()
                                  : Text(
                                      displayStructureName,
                                      style: TextStyle(
                                        fontSize: screenSize.width *
                                            (isTablet
                                                ? 0.032
                                                : 0.06), // Taille relative
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            Row(
                              children: [
                                // Conteneur de la date
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenSize.width *
                                        (isTablet ? 0.018 : 0.03),
                                    vertical: screenSize.height *
                                        (isTablet ? 0.01 : 0.006),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(
                                        screenSize.width *
                                            (isTablet ? 0.025 : 0.05)),
                                  ),
                                  child: Text(
                                    DateFormat('EEEE d MMMM', 'fr_FR')
                                        .format(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: screenSize.width *
                                          (isTablet ? 0.018 : 0.035),
                                      color: Colors.white.withOpacity(0.95),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Bouton de déconnexion
                                IconButton(
                                  icon: Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                    size: screenSize.width *
                                        (isTablet ? 0.028 : 0.05),
                                  ),
                                  tooltip: 'Se déconnecter',
                                  onPressed: _logout,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  splashRadius: screenSize.width *
                                      (isTablet ? 0.028 : 0.05),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Contenu principal avec adaptation pour iPad
              Expanded(
                child: isTablet
                    ? _buildTabletContent(
                        features) // Layout spécifique pour iPad
                    : _buildPhoneContent(
                        features), // Layout original pour iPhone
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            type: BottomNavigationBarType.fixed,
            currentIndex: 1, // Home est sélectionné
            items: [
              // Premier item - Dashboard
              BottomNavigationBarItem(
                icon: Image.asset(
                  'assets/images/Icone_Dashboard.png',
                  width: screenSize.width *
                      (isTablet ? 0.07 : 0.14), // Taille relative
                  height: screenSize.width * (isTablet ? 0.07 : 0.14),
                ),
                label: "Dashboard",
              ),

              // Deuxième item - Home (Maison)
              BottomNavigationBarItem(
                icon: Image.asset(
                  'assets/images/maison_icon.png',
                  width: screenSize.width * (isTablet ? 0.07 : 0.14),
                  height: screenSize.width * (isTablet ? 0.07 : 0.14),
                ),
                label: "Accueil",
              ),

              // Troisième item - Ajouter enfant
              BottomNavigationBarItem(
                icon: _buildMessagesNavIcon(
                    screenSize.width * (isTablet ? 0.07 : 0.14)),
                activeIcon: _buildMessagesNavIcon(
                    screenSize.width * (isTablet ? 0.07 : 0.14)),
                label: "Messages",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessagesNavIcon(double size) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();

    Widget baseIcon() => Image.asset(
          'assets/images/Icone_Echanges.png',
          width: size,
          height: size,
        );

    if (email == null) {
      return baseIcon();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(email).snapshots(),
      builder: (context, snapshot) {
        int unread = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? const {};
          unread = (data['unreadMessages'] ?? 0) as int;
        }

        if (unread <= 0) {
          return baseIcon();
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseIcon(),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  unread > 9 ? '9+' : unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFallbackAvatarResponsive(
      String name, bool isTablet, double innerAvatarSize, double initialsSize) {
    return Container(
      width: innerAvatarSize,
      height: innerAvatarSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: initialsSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  // Pour la version iPhone
  Widget _buildChildAvatar(Map<String, dynamic> child, bool isTablet) {
    final isBoy = child['gender'] == 'Garçon';
    final displayName = child['firstName'] ?? 'Enfant';
    final photoUrl = child['photoUrl'];
    final childId = child['id'];

    // Utilisez MediaQuery pour obtenir la taille de l'écran
    final screenSize = MediaQuery.of(context).size;

    // Calculer les tailles en fonction de la largeur de l'écran
    final double avatarSize = isTablet
        ? screenSize.width * 0.07 // 7% de la largeur de l'écran pour iPad
        : screenSize.width * 0.12; // 12% de la largeur de l'écran pour iPhone

    final double innerAvatarSize =
        avatarSize * 0.95; // 95% de la taille de l'avatar
    final double fontSize = isTablet
        ? screenSize.width * 0.016 // 1.6% de la largeur pour iPad
        : screenSize.width * 0.026; // 2.6% de la largeur pour iPhone

    final double initialsSize =
        avatarSize * 0.4; // 40% de la taille de l'avatar

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _handleChildTap(child),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isBoy
                        ? [primaryColor.withOpacity(0.7), primaryColor]
                        : [Colors.pink.withOpacity(0.7), Colors.pink],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isBoy ? primaryColor : Colors.pink).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            photoUrl,
                            width: innerAvatarSize,
                            height: innerAvatarSize,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildFallbackAvatarResponsive(displayName,
                                    isTablet, innerAvatarSize, initialsSize),
                          ),
                        )
                      : _buildFallbackAvatarResponsive(
                          displayName, isTablet, innerAvatarSize, initialsSize),
                ),
              ),
            ),

            // Badge de notification pour messages non lus
          ],
        ),
        SizedBox(
            height: isTablet
                ? avatarSize * 0.12
                : avatarSize * 0.08), // Espace proportionnel
        Text(
          displayName,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Avatar par défaut avec l'initiale du prénom
  Widget _buildFallbackAvatar(String name, bool isTablet) {
    final double innerAvatarSize = isTablet ? 66.0 : 46.0;
    final double initialsSize = isTablet ? 28.0 : 20.0;

    return Container(
      width: innerAvatarSize,
      height: innerAvatarSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: initialsSize,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  // Dans home_screen.dart, remplacez ENTIÈREMENT cette méthode _buildGridItem :

  Widget _buildGridItem(BuildContext context, String route, String name,
      String imagePath, bool isTablet) {
    // Tailles adaptées pour tablette avec proportions améliorées
    final bool isAgendaIcon = route == '/agenda';
    final double baseSize = isTablet ? 80.0 : 60.0;
    final double imageSize = isAgendaIcon ? baseSize * 0.85 : baseSize;
    final double fontSize = isTablet ? 16.0 : 10.0;

    // Vérifier si c'est l'icône des échanges pour ajouter le badge de notification
    final bool isExchangeIcon = route == '/exchanges';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
      elevation: isTablet ? 4 : 2, // Élévation plus prononcée sur iPad
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16.0 : 6.0,
            vertical: isTablet ? 12.0 : 6.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Image de l'icône
                    Image.asset(
                      imagePath,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported,
                        size: imageSize,
                        color: primaryColor,
                      ),
                    ),

                    // Badge de notification pour les échanges - CORRIGÉ
                    if (isExchangeIcon)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseAuth.instance.currentUser?.email ==
                                  null
                              ? null
                              : FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(FirebaseAuth.instance.currentUser!.email!
                                      .toLowerCase())
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return const SizedBox.shrink();
                            }

                            final data = snapshot.data!.data()
                                    as Map<String, dynamic>? ??
                                const {};
                            final int unreadMessages =
                                (data['unreadMessages'] ?? 0) as int;
                            final bool hasBadge = unreadMessages > 0;

                            if (!hasBadge) {
                              return const SizedBox.shrink();
                            }

                            return Container(
                              padding: EdgeInsets.all(isTablet ? 6 : 4),
                              decoration: BoxDecoration(
                                color: primaryRed,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                unreadMessages.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 14 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (isAgendaIcon && _todayAgendaCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _buildAgendaBadge(isTablet),
                      ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 10 : 1),
              Text(
                name,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
