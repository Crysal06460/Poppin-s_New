import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poppins_app/screens/child_profile_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String structureName = "Chargement...";
  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> upcomingBirthdays = [];
  bool isLoading = true;
  bool hasChildren = false;

  // Variable pour stocker le type de structure
  String structureType = "AssistanteMaternelle"; // Valeur par défaut

  // Variables pour identifier le membre actuel
  String currentUserEmail = "";

  // Définition des thèmes de couleurs
  late Color primaryColor;
  late Color secondaryColor;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting().then((_) => _fetchData());
  }

  bool _hasShownBirthdayAlert = false;
  static const String _birthdayAlertShownKey = 'birthday_alert_shown_date';

  // Méthode pour définir les couleurs en fonction du type de structure
  void _setThemeColors() {
    // Utilisation des couleurs de la palette (identique pour tous les types)
    primaryColor = const Color(0xFF3D9DF2); // Bleu #3D9DF2
    secondaryColor = const Color(0xFFDFE9F2); // Bleu clair #DFE9F2
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
      await FirebaseAuth.instance.signOut();

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
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // C'est un membre MAM, utiliser structureId au lieu de l'ID utilisateur
          structureDocId = userData['structureId'];
          isMamMember = true;
          print(
              "👤 Utilisateur identifié comme membre MAM pour la structure: $structureDocId");
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

      String fetchedStructureName =
          structureDoc['structureName'] ?? "Ma Structure";

      // Récupération du type de structure existant
      String fetchedStructureType = "AssistanteMaternelle"; // Valeur par défaut

      if (structureDoc.data() != null) {
        final data = structureDoc.data() as Map<String, dynamic>;
        if (data.containsKey('structureType')) {
          fetchedStructureType = data['structureType'];
        } else {
          // Ajouter le champ s'il n'existe pas
          await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureDocId)
              .update({'structureType': fetchedStructureType});
        }
      }

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
      // Dans home_screen.dart, remplacez le bloc de code pour le filtrage des enfants (lignes ~124-145)

// NOUVEAU: Filtrer les enfants selon le type de structure et le rôle de l'utilisateur
      List<Map<String, dynamic>> filteredChildren = [];

      if (fetchedStructureType == "MAM") {
        // Tous les membres ne voient que leurs enfants assignés
        filteredChildren = allChildren.where((child) {
          // Vérifier si l'enfant est assigné à ce membre
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
          bool isAssigned = assignedEmail == currentUserEmail;

          print(
              "🔍 DEBUG - Enfant: ${child['firstName']}, assignedEmail: '$assignedEmail', currentUserEmail: '$currentUserEmail', isAssigned: $isAssigned");

          // Comparaison stricte, et on s'assure que les deux emails sont en minuscules
          return assignedEmail == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 Membre MAM: affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Assistante Maternelle individuelle: affichage de tous les enfants");
      }

// Remplacer les logs de diagnostic pour ne plus mentionner le fondateur
      if (fetchedStructureType == "MAM") {
        print(
            "🔍 DIAGNOSTIC - Type de structure: MAM, Utilisateur: $currentUserEmail");
        print(
            "🔍 DIAGNOSTIC - Nombre total d'enfants dans la structure: ${allChildren.length}");
        print(
            "🔍 DIAGNOSTIC - Nombre d'enfants filtrés pour cet utilisateur: ${filteredChildren.length}");

        print("🔍 LISTE DÉTAILLÉE DES ENFANTS:");
        for (var child in allChildren) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ??
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
      List<Map<String, dynamic>> todayChildren = filteredChildren
          .where((child) =>
              child['schedule'] != null &&
              child['schedule'].containsKey(capitalizedWeekday))
          .toList();

      setState(() {
        structureName = fetchedStructureName;
        structureType = fetchedStructureType;
        children = todayChildren;
        // Vérifier si le membre a des enfants qui lui sont assignés
        hasChildren = filteredChildren.isNotEmpty;
        isLoading = false;
      });

      // Définir les couleurs après avoir récupéré le type de structure
      _setThemeColors();

      // Trouver les anniversaires à venir (uniquement parmi les enfants filtrés)
      _findUpcomingBirthdays(filteredChildren);

      // Pour les MAM: vérifier s'il y a d'autres membres que le fondateur
      if (structureType == "MAM") {
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureDocId)
            .collection('members')
            .get();

        // Compter le nombre de membres (y compris le fondateur)
        final bool hasNoMembers = membersSnapshot.docs.isEmpty;
        final bool hasOnlyOneMember = membersSnapshot.docs.length <= 1;

        // Si c'est une MAM et qu'il n'y a que le fondateur, afficher le popup d'ajout de membres
        if (hasNoMembers || hasOnlyOneMember) {
          print(
              "⚠️ MAM avec peu de membres, affichage du popup pour ajouter des membres...");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAddMAMMembersPopup();
          });
        }
      }

// SÉPARATION DE LA CONDITION - Cette vérification doit être indépendante
      if (!hasChildren) {
        // Pour tous les cas: si aucun enfant, afficher le popup d'ajout d'enfant
        print("⚠️ Aucun enfant trouvé, affichage du popup...");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAddChildPopup();
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

  void _findUpcomingBirthdays(List<Map<String, dynamic>> allChildren) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final lastShownDate = prefs.getString(_birthdayAlertShownKey) ?? '';

    final bool alreadyShownToday = lastShownDate == todayFormatted;

    List<Map<String, dynamic>> birthdayChildren = [];
    List<Map<String, dynamic>> todayBirthdayChildren = [];

    for (var child in allChildren) {
      if (child['birthdate'] == null) continue;

      try {
        // Améliorer la gestion du format de date ISO
        DateTime birthdate;
        final birthdateStr = child['birthdate'];

        // Pour corriger le format de date ISO
        if (birthdateStr is String) {
          // Gérer explicitement le format ISO des dates Firebase
          birthdate = DateTime.parse(birthdateStr.split('T')[0]);
        } else {
          print(
              "⚠️ Format de date non reconnu pour ${child['firstName']}: $birthdateStr");
          continue;
        }

        // Vérifier si c'est aujourd'hui (même jour et même mois)
        bool isToday =
            today.day == birthdate.day && today.month == birthdate.month;

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

        print(
            "🗓️ Prochain anniversaire calculé pour ${child['firstName']}: ${nextBirthday.toString()}");

        // MÉTHODE PRÉCISE: Calculer les jours exacts entre aujourd'hui et l'anniversaire
        int daysUntilBirthday = 0;

        // Cloner la date actuelle pour itération
        DateTime currentDate = DateTime(today.year, today.month, today.day);

        // Compter chaque jour jusqu'à l'anniversaire
        while (currentDate.year != nextBirthday.year ||
            currentDate.month != nextBirthday.month ||
            currentDate.day != nextBirthday.day) {
          daysUntilBirthday++;
          currentDate = currentDate.add(Duration(days: 1));
        }

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

      if (todayBirthdayChildren.isNotEmpty &&
          !alreadyShownToday &&
          !_hasShownBirthdayAlert) {
        print(
            "🎉 Affichage de l'alerte d'anniversaire (première fois aujourd'hui)!");

        _hasShownBirthdayAlert = true;
        prefs.setString(_birthdayAlertShownKey, todayFormatted);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showBirthdayAlert(todayBirthdayChildren);
        });
      }
    });
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
                              'assets/images/birthday_img.png',
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
                          Text(
                            "N'oubliez pas de souhaiter un joyeux anniversaire !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade700,
                              fontSize: screenSize.width * 0.035,
                            ),
                          ),
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

// Nouveau layout pour iPad
  // Version complète améliorée de la méthode _buildTabletContent
  // Correction du problème d'espacement et de débordement dans la grille des fonctionnalités
// Version améliorée de _buildTabletContent avec répartition verticale des icônes

  // Mise à jour de _buildTabletContent pour utiliser un design similaire à iPhone mais avec espacement adapté
// Code optimisé pour fonctionner avec des proportions fixes basées sur des pourcentages

  // Version optimisée avec espacement vertical uniforme (7 sections égales)
  Widget _buildTabletContent(List<Map<String, dynamic>> features) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panneau latéral gauche (enfants présents + anniversaires) - 40% de l'écran
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre avec icône
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/Icone_Enfant_Present.png',
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.people_alt_rounded,
                            color: primaryColor,
                            size: 80,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Enfants présents aujourd'hui",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Liste des enfants présents
                    Expanded(
                      child: children.isEmpty
                          ? Center(
                              child: Text(
                                "Aucun enfant prévu aujourd'hui",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: children.length,
                              itemBuilder: (context, index) =>
                                  _buildChildAvatar(children[index], true),
                            ),
                    ),

                    // Section des anniversaires
                    if (upcomingBirthdays.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                                  size: 24,
                                  color: const Color(0xFFD94350),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Anniversaires à venir",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFD94350),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Limiter la hauteur avec un container à défilement
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: 150),
                              child: ListView(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                children: upcomingBirthdays.map((b) {
                                  String message;
                                  if (b['daysUntilBirthday'] == 0) {
                                    message = "Aujourd'hui";
                                  } else if (b['daysUntilBirthday'] == 1) {
                                    message = "Demain";
                                  } else if (b['daysUntilBirthday'] == 2) {
                                    message = "Après-demain";
                                  } else {
                                    message =
                                        "Dans ${b['daysUntilBirthday']} jours";
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "• ${b['firstName']}",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: b['daysUntilBirthday'] == 0
                                                ? Colors.orange.shade700
                                                : Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
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

          // Panneau de droite (fonctionnalités) - 60% de l'écran
          Expanded(
            flex: 6,
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre de la section fonctionnalités
                    Text(
                      "Fonctionnalités",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Nouvelle approche avec répartition exacte en 7 sections
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculer la taille de l'écran disponible
                          final double totalHeight = constraints.maxHeight;

                          // On veut 7 sections égales:
                          // 1. Espace (1/7 de la hauteur)
                          // 2. Première rangée (1/7 de la hauteur)
                          // 3. Espace (1/7 de la hauteur)
                          // 4. Deuxième rangée (1/7 de la hauteur)
                          // 5. Espace (1/7 de la hauteur)
                          // 6. Troisième rangée (1/7 de la hauteur)
                          // 7. Espace (1/7 de la hauteur)

                          final double sectionHeight = totalHeight / 7;
                          final double itemHeight = sectionHeight;

                          // Diviser les fonctionnalités en 3 rangées
                          final List<List<Map<String, dynamic>>> rows = [
                            features.sublist(0, 4), // Première rangée: 0-3
                            features.sublist(4, 8), // Deuxième rangée: 4-7
                            features.sublist(8, 12), // Troisième rangée: 8-11
                          ];

                          return Column(
                            children: [
                              // Section 1: Espace (1/7 de la hauteur)
                              SizedBox(height: sectionHeight),

                              // Section 2: Première rangée (1/7 de la hauteur)
                              Container(
                                height: itemHeight,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: rows[0]
                                      .map((feature) => Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              child: _buildTabletGridItem(
                                                context,
                                                feature['route'] as String,
                                                feature['name'] as String,
                                                feature['imagePath'] as String,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),

                              // Section 3: Espace (1/7 de la hauteur)
                              SizedBox(height: sectionHeight),

                              // Section 4: Deuxième rangée (1/7 de la hauteur)
                              Container(
                                height: itemHeight,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: rows[1]
                                      .map((feature) => Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              child: _buildTabletGridItem(
                                                context,
                                                feature['route'] as String,
                                                feature['name'] as String,
                                                feature['imagePath'] as String,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),

                              // Section 5: Espace (1/7 de la hauteur)
                              SizedBox(height: sectionHeight),

                              // Section 6: Troisième rangée (1/7 de la hauteur)
                              Container(
                                height: itemHeight,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: rows[2]
                                      .map((feature) => Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              child: _buildTabletGridItem(
                                                context,
                                                feature['route'] as String,
                                                feature['name'] as String,
                                                feature['imagePath'] as String,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),

                              // Section 7: Espace (1/7 de la hauteur)
                              SizedBox(height: sectionHeight),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Nouvelle méthode pour construire des vignettes qui ressemblent exactement au design iPhone
  Widget _buildTabletGridItem(
      BuildContext context, String route, String name, String imagePath) {
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
              child: Center(
                child: Image.asset(
                  imagePath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.image_not_supported,
                    size: 60,
                    color: primaryColor,
                  ),
                ),
              ),
            ),

            // Texte centré en dessous
            Expanded(
              flex: 1, // Proportions pour le texte
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
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
      context.go('/child-info');
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

    // Définir les couleurs avant de construire l'interface
    _setThemeColors();

    // Déterminer si on est sur iPad
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // Liste des fonctionnalités avec leur route, nom et image
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
        'route': '/exchanges',
        'name': 'Échanges',
        'imagePath': 'assets/images/Icone_Echanges.png'
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
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
                  isTablet
                      ? 24
                      : 10, // Plus grand padding horizontal sur tablette
                  16,
                  isTablet ? 24 : 10,
                  isTablet ? 16 : 5, // Plus grand padding bas sur tablette
                ),
                child: Column(
                  children: [
                    // Nom de la structure et date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            structureName,
                            style: TextStyle(
                              fontSize: isTablet
                                  ? 32
                                  : 24, // Plus grande police sur tablette
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
                                horizontal: isTablet
                                    ? 18
                                    : 12, // Plus grand padding sur tablette
                                vertical: isTablet
                                    ? 10
                                    : 6, // Plus grand padding sur tablette
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius:
                                    BorderRadius.circular(isTablet ? 25 : 20),
                              ),
                              child: Text(
                                DateFormat('EEEE d MMMM', 'fr_FR')
                                    .format(DateTime.now()),
                                style: TextStyle(
                                  fontSize: isTablet
                                      ? 18
                                      : 14, // Plus grande police sur tablette
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
                                size: isTablet
                                    ? 28
                                    : 20, // Plus grande icône sur tablette
                              ),
                              tooltip: 'Se déconnecter',
                              onPressed: _logout,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              splashRadius: isTablet ? 28 : 20,
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
                ? _buildTabletContent(features) // Layout spécifique pour iPad
                : _buildPhoneContent(features), // Layout original pour iPhone
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: 1, // Home est sélectionné
        items: [
          // Premier item - Dashboard
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Dashboard.png',
              width: isTablet ? 72 : 60, // Taille ajustée pour iPad
              height: isTablet ? 72 : 60,
            ),
            label: "Dashboard",
          ),

          // Deuxième item - Home (Maison)
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/maison_icon.png',
              width: isTablet ? 72 : 60,
              height: isTablet ? 72 : 60,
            ),
            label: "Home",
          ),

          // Troisième item - Ajouter enfant
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Ajout_Enfant.png',
              width: isTablet ? 72 : 60,
              height: isTablet ? 72 : 60,
            ),
            label: "Ajouter",
          ),
        ],
      ),
    );
  }

  // Widget pour l'avatar d'un enfant
  // Modifiez le Widget _buildChildAvatar pour gérer l'appel async correctement
  Widget _buildChildAvatar(Map<String, dynamic> child, bool isTablet) {
    final isBoy = child['gender'] == 'Garçon';
    final displayName = child['firstName'] ?? 'Enfant';
    final photoUrl = child['photoUrl'];

    // Tailles adaptées pour tablette
    final double avatarSize = isTablet ? 70.0 : 50.0;
    final double innerAvatarSize = isTablet ? 66.0 : 46.0;
    final double fontSize = isTablet ? 16.0 : 11.0;
    final double initialsSize = isTablet ? 28.0 : 20.0;

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            // Navigation vers l'écran de profil détaillé de l'enfant
            String structId = await _getStructureId();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChildProfileDetailsScreen(
                  childId: child['id'],
                  structureId: structId,
                ),
              ),
            );
          },
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
                  color: (isBoy ? primaryColor : Colors.pink).withOpacity(0.3),
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
                            _buildFallbackAvatar(displayName, isTablet),
                      ),
                    )
                  : _buildFallbackAvatar(displayName, isTablet),
            ),
          ),
        ),
        SizedBox(height: isTablet ? 8 : 4),
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

  // Élément de la grille de fonctionnalités avec image
  // Version améliorée de _buildGridItem pour une meilleure apparence sur iPad
  Widget _buildGridItem(BuildContext context, String route, String name,
      String imagePath, bool isTablet) {
    // Tailles adaptées pour tablette avec proportions améliorées
    final double imageSize = isTablet ? 80.0 : 60.0;
    final double fontSize = isTablet ? 16.0 : 10.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
      elevation: isTablet ? 4 : 2, // Élévation plus prononcée sur iPad
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        child: Container(
          // Utiliser un Container avec padding au lieu de Padding directement
          // pour mieux contrôler la taille et le centrage
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16.0 : 6.0,
            vertical: isTablet ? 12.0 : 6.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
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
