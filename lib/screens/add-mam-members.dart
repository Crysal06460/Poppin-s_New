import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;

class AddMAMMembersScreen extends StatefulWidget {
  const AddMAMMembersScreen({Key? key}) : super(key: key);

  @override
  _AddMAMMembersScreenState createState() => _AddMAMMembersScreenState();
}

class _AddMAMMembersScreenState extends State<AddMAMMembersScreen> {
  // Liste pour stocker les membres de la MAM
  final List<MAMMember> _members = [];

  // Informations sur le fondateur (utilisateur actuel)
  String _founderFirstName = "";
  String _founderLastName = "";
  String _founderEmail = "";
  String _structureName = "";
  bool _isLoading = true;

  // Informations sur l'abonnement
  int _maxMemberCount = 4; // Par défaut

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  Future<void> _loadCurrentUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }

      // Récupérer les informations de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      if (structureDoc.exists) {
        final structureData = structureDoc.data() as Map<String, dynamic>;

        // Récupérer maxMemberCount directement depuis le document de la structure
        // Cette valeur est mise à jour par l'écran SubscriptionConfirmedScreen
        if (structureData.containsKey('maxMemberCount')) {
          setState(() {
            _maxMemberCount = structureData['maxMemberCount'] ?? 4;
          });
          print(
              "📌 maxMemberCount récupéré depuis la structure: $_maxMemberCount");
        } else {
          // Si maxMemberCount n'existe pas dans la structure, essayer de le récupérer depuis l'abonnement
          await _fetchSubscriptionInfo(user.uid);
        }

        // Récupérer les membres existants pour voir s'il y a déjà des membres
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(user.uid)
            .collection('members')
            .get();

        // Chercher les informations du fondateur
        String firstName = "";
        String lastName = "";
        bool founderFound = false;

        // Vérifier si le document founder existe déjà
        final existingMembers = membersSnapshot.docs;

        for (var doc in existingMembers) {
          final memberData = doc.data();
          // Si on trouve un membre avec isFounder = true, c'est le fondateur
          if (memberData['isFounder'] == true) {
            firstName = memberData['firstName'] ?? "";
            lastName = memberData['lastName'] ?? "";
            founderFound = true;
            break;
          }
        }

        // Si on n'a pas trouvé le fondateur, prendre les informations de la structure
        if (!founderFound) {
          firstName = structureData['ownerFirstName'] ?? "";
          lastName = structureData['ownerLastName'] ?? "";
        }

        setState(() {
          _founderFirstName = firstName;
          _founderLastName = lastName;
          _founderEmail = user.email ?? "";
          _structureName = structureData['structureName'] ?? "Notre MAM";

          // Ajouter le fondateur comme premier membre
          _members.add(MAMMember(
            firstName: _founderFirstName,
            lastName: _founderLastName,
            email: _founderEmail,
            isFounder:
                true, // On garde cette propriété pour l'interface utilisateur
          ));

          _isLoading = false;
        });
      } else {
        context.go('/create-structure');
      }
    } catch (e) {
      print("🚨 Erreur lors du chargement des informations: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Récupérer les informations d'abonnement
  Future<void> _fetchSubscriptionInfo(String userId) async {
    try {
      // Récupérer les informations d'abonnement depuis Firestore
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (subscriptionDoc.docs.isNotEmpty) {
        final subscriptionData = subscriptionDoc.docs.first.data();

        // Mettre à jour le nombre maximum de membres en fonction de l'abonnement
        setState(() {
          _maxMemberCount = subscriptionData['memberCount'] ?? 4;
        });

        // Sauvegarder cette valeur dans le document structure pour les accès futurs
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(userId)
            .update({'maxMemberCount': _maxMemberCount});

        print(
            "📊 Abonnement trouvé dans Firestore: maximum $_maxMemberCount membres");
      } else {
        // Aucun abonnement trouvé, utiliser la valeur par défaut (4)
        print(
            "⚠️ Aucun abonnement actif trouvé, utilisation de la valeur par défaut (4 membres)");
      }
    } catch (e) {
      print(
          "🚨 Erreur lors de la récupération des informations d'abonnement: $e");
      // En cas d'erreur, garder la valeur par défaut
    }
  }

  // Ajouter un nouveau membre à la liste
  void _addNewMember() {
    if (_members.length >= _maxMemberCount) {
      // Maximum de membres atteint selon l'abonnement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Votre abonnement MAM est limité à $_maxMemberCount membre${_maxMemberCount > 1 ? 's' : ''}"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _members.add(MAMMember(
        firstName: "",
        lastName: "",
        email: "",
        isFounder: false,
      ));
    });
  }

  // Supprimer un membre de la liste
  void _removeMember(int index) {
    if (index > 0) {
      // Ne pas supprimer le fondateur
      setState(() {
        _members.removeAt(index);
      });
    }
  }

  Future<void> _saveMembers() async {
    // Vérifier que tous les champs sont remplis
    bool isValid = true;
    String errorMessage = "";

    for (int i = 1; i < _members.length; i++) {
      final member = _members[i];
      if (member.firstName.isEmpty ||
          member.lastName.isEmpty ||
          member.email.isEmpty) {
        isValid = false;
        errorMessage = "Veuillez remplir tous les champs pour chaque membre";
        break;
      }

      // Vérifier le format de l'email
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(member.email)) {
        isValid = false;
        errorMessage =
            "L'adresse email de ${member.firstName} n'est pas valide";
        break;
      }
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Vérifier que le nombre total de membres respecte la limite d'abonnement
      if (_members.length > _maxMemberCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Le nombre de membres dépasse la limite de votre abonnement ($_maxMemberCount membres)"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Référence à la collection des membres de la MAM
      final membersCollection = FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('members');

      // Supprimer tous les membres existants
      final existingMembers = await membersCollection.get();
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in existingMembers.docs) {
        batch.delete(doc.reference);
      }

      // Exécuter le batch de suppressions
      await batch.commit();

      // Créer un nouveau batch pour les ajouts
      batch = FirebaseFirestore.instance.batch();

      // Ajouter tous les membres (y compris le fondateur) avec des ID séquentiels
      for (int i = 0; i < _members.length; i++) {
        final member = _members[i];
        final memberId =
            'member_${i + 1}'; // Créer des IDs séquentiels (member_1, member_2, etc.)

        batch.set(membersCollection.doc(memberId), {
          'firstName': member.firstName,
          'lastName': member.lastName,
          'email': member.email.toLowerCase(),
          'isFounder': i == 0, // Le premier membre est le fondateur
          'memberNumber': i + 1, // Numéro séquentiel du membre
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Envoyer l'email d'invitation pour les membres autres que le fondateur
        if (i > 0) {
          await _sendInvitationEmail(member);
        }
      }

      // Exécuter le batch d'ajouts
      await batch.commit();

      print("✅ Tous les membres ont été enregistrés avec des IDs séquentiels");

      // NOUVELLE PARTIE : Attribuer les enfants existants sans assignation aux membres de la MAM
      try {
        // Récupérer tous les enfants qui n'ont pas d'assistante maternelle assignée
        final childrenSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(user.uid)
            .collection('children')
            .where('assignedMemberEmail', isNull: true)
            .get();

        print(
            "🧒 Nombre d'enfants sans assignation: ${childrenSnapshot.docs.length}");

        if (childrenSnapshot.docs.isNotEmpty) {
          // Récupérer tous les membres pour la répartition (y compris le fondateur)
          final List<MAMMember> allMembers = List.from(_members);
          int memberIndex = 0;

          // Créer des batches pour les mises à jour (pour optimiser les performances)
          WriteBatch batch = FirebaseFirestore.instance.batch();
          int batchCount = 0;

          // Pour chaque enfant sans assignation, l'assigner à un membre de façon équilibrée
          for (var childDoc in childrenSnapshot.docs) {
            // Assigner l'enfant au membre actuel (distribution circulaire)
            final MAMMember currentMember = allMembers[memberIndex];

            batch.update(childDoc.reference, {
              'assignedMemberEmail': currentMember.email.toLowerCase(),
              'memberNumber':
                  memberIndex + 1, // Ajouter également le numéro du membre
            });

            print(
                "👶➡️👩‍⚕️ Assignation de l'enfant ${childDoc.id} à ${currentMember.firstName} ${currentMember.lastName}");

            // Passer au membre suivant (de façon circulaire)
            memberIndex = (memberIndex + 1) % allMembers.length;
            batchCount++;

            // Exécuter par lots de 500 maximum (limite Firestore)
            if (batchCount >= 500) {
              await batch.commit();
              batch = FirebaseFirestore.instance.batch();
              batchCount = 0;
            }
          }

          // Exécuter le dernier batch s'il reste des opérations
          if (batchCount > 0) {
            await batch.commit();
          }

          print("✅ Tous les enfants ont été assignés aux membres de la MAM");
        }
      } catch (e) {
        print("⚠️ Erreur lors de l'assignation des enfants aux membres: $e");
        // Ne pas bloquer le processus en cas d'erreur
      }

      // Afficher un message de succès au lieu de rediriger
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Membres sauvegardés avec succès !"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("🚨 Erreur lors de la sauvegarde des membres: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Une erreur est survenue: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

// Terminer l'ajout de membres et rediriger vers l'accueil
  Future<void> _finishAndGoHome() async {
    await _saveMembers();

    // Attendre un petit délai pour que l'utilisateur voie le message de succès
    await Future.delayed(Duration(seconds: 1));

    // Redirection vers la page d'accueil
    if (mounted) {
      context.go('/home');
    }
  }

  // Envoyer un email d'invitation à un membre
  Future<void> _sendInvitationEmail(MAMMember member) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      // Récupérer les informations de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      final structureName = structureDoc.data()?['structureName'] ?? 'MAM';

      // Normaliser l'email (en minuscules)
      final String normalizedEmail = member.email.toLowerCase();

      // Définir la date d'expiration (30 jours à partir de maintenant)
      final DateTime expirationDate = DateTime.now().add(Duration(days: 30));

      // Créer l'invitation dans Firestore
      await FirebaseFirestore.instance.collection('invitations').add({
        'email': normalizedEmail,
        'type': 'mamMember',
        'structureId': user.uid,
        'structureName': structureName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationDate),
        'status': 'active',
      });

      print("✅ Invitation pour membre MAM enregistrée dans Firestore");

      // Construire les données du template pour l'email
      final templateData = {
        'firstName': member.firstName,
        'lastName': member.lastName,
        'structureName': structureName,
        'structureId': user.uid,
        'inviterName': _founderFirstName + ' ' + _founderLastName,
        'androidLink':
            'https://play.google.com/store/apps/details?id=com.example.poppins_app',
        'iosLink': 'https://apps.apple.com/app/id123456789',
        'download_link': 'https://poppins_app.com/download',
        'year': DateTime.now().year.toString(),
        'to': normalizedEmail,
      };

      // Ajouter l'email à la file d'attente d'envoi
      await FirebaseFirestore.instance.collection('emailQueue').add({
        'to': normalizedEmail,
        'template': 'mam-member-invitation',
        'subject':
            'Invitation à rejoindre la MAM "${structureName}" sur Poppins',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
        'retryCount': 0,
        'templateData': templateData
      });

      print("✅ Invitation envoyée au membre MAM: $normalizedEmail");

      // Ajouter un message pour indiquer que l'email a été envoyé
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Invitation envoyée à ${member.firstName} ${member.lastName}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur lors de l'envoi de l'invitation au membre MAM: $e");
      // Continue même si l'email échoue
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Membres de la MAM",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: const Color(0xFF16A085),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: isTablet ? _buildTabletContent(screenSize) : _buildPhoneContent(),
    );
  }

  // Construire la liste des widgets de membres
  List<Widget> _buildMembersList() {
    List<Widget> memberWidgets = [];

    for (int i = 0; i < _members.length; i++) {
      memberWidgets.add(
        _buildMemberCard(i, _members[i]),
      );
      memberWidgets.add(const SizedBox(height: 16));
    }

    return memberWidgets;
  }

  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et explication
          Text(
            "Ajouter les membres de votre MAM",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF16A085),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Votre abonnement vous permet d'ajouter jusqu'à ${_maxMemberCount - 1} autre${_maxMemberCount > 2 ? 's' : ''} membre${_maxMemberCount > 2 ? 's' : ''} (${_maxMemberCount} au total).",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 20),

          // Liste des membres
          ..._buildMembersList(),

          const SizedBox(height: 20),

          // Bouton pour ajouter un membre
          if (_members.length < _maxMemberCount)
            Center(
              child: OutlinedButton.icon(
                onPressed: _addNewMember,
                icon: const Icon(Icons.add),
                label: const Text("Ajouter un autre membre"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A085),
                  side: const BorderSide(color: Color(0xFF16A085)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

          const SizedBox(height: 40),

          // Boutons d'action
          Column(
            children: [
              // Bouton pour sauvegarder sans quitter
              if (_members.length >
                  1) // Afficher seulement s'il y a des membres ajoutés
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    onPressed: _saveMembers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "SAUVEGARDER",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Boutons principaux
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text(
                      "PASSER",
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _finishAndGoHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A085),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "TERMINER",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletContent(Size screenSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculer des dimensions en pourcentages
        final double sideMargin = maxWidth * 0.04; // 4% de marge sur les côtés
        final double columnGap =
            maxWidth * 0.03; // 3% d'écart entre les colonnes

        return Padding(
          padding: EdgeInsets.fromLTRB(
              sideMargin, maxHeight * 0.03, sideMargin, maxHeight * 0.02),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panneau gauche - Informations et instructions
              Expanded(
                flex: 4,
                child: Container(
                  margin: EdgeInsets.only(right: columnGap),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF16A085),
                        const Color(0xFF16A085).withOpacity(0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A085).withOpacity(0.3),
                        offset: const Offset(0, 8),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(maxWidth * 0.035),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo et titre
                        Row(
                          children: [
                            Container(
                              width: maxWidth * 0.08,
                              height: maxWidth * 0.08,
                              padding: EdgeInsets.all(maxWidth * 0.015),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.people_alt_rounded,
                                color: const Color(0xFF16A085),
                                size: maxWidth * 0.04,
                              ),
                            ),
                            SizedBox(width: maxWidth * 0.02),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Membres de la MAM",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.028,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _structureName,
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.018,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: maxHeight * 0.04),

                        // Instructions
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.025),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                    size: maxWidth * 0.022,
                                  ),
                                  SizedBox(width: maxWidth * 0.015),
                                  Text(
                                    "Informations",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.02,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: maxHeight * 0.02),
                              Text(
                                "Votre abonnement vous permet d'ajouter jusqu'à ${_maxMemberCount - 1} autre${_maxMemberCount > 2 ? 's' : ''} membre${_maxMemberCount > 2 ? 's' : ''} (${_maxMemberCount} au total).",
                                style: TextStyle(
                                  fontSize: maxWidth * 0.016,
                                  color: Colors.white.withOpacity(0.95),
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.025),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: maxWidth * 0.02,
                                  vertical: maxHeight * 0.01,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.group,
                                      color: const Color(0xFF16A085),
                                      size: maxWidth * 0.018,
                                    ),
                                    SizedBox(width: maxWidth * 0.01),
                                    Text(
                                      "${_members.length} / $_maxMemberCount membres",
                                      style: TextStyle(
                                        fontSize: maxWidth * 0.016,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF16A085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Avantages MAM
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.025),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Avantages de la MAM",
                                style: TextStyle(
                                  fontSize: maxWidth * 0.018,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.015),
                              ...[
                                "Collaboration entre assistantes maternelles",
                                "Partage des responsabilités",
                                "Flexibilité pour les parents",
                                "Suivi coordonné des enfants"
                              ].map((advantage) => Padding(
                                    padding: EdgeInsets.only(
                                        bottom: maxHeight * 0.008),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.white,
                                          size: maxWidth * 0.015,
                                        ),
                                        SizedBox(width: maxWidth * 0.01),
                                        Expanded(
                                          child: Text(
                                            advantage,
                                            style: TextStyle(
                                              fontSize: maxWidth * 0.014,
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Panneau droit - Formulaire des membres
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        offset: const Offset(0, 4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(maxWidth * 0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre section membres
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  color: const Color(0xFF16A085),
                                  size: maxWidth * 0.025,
                                ),
                                SizedBox(width: maxWidth * 0.015),
                                Text(
                                  "Ajouter les membres",
                                  style: TextStyle(
                                    fontSize: maxWidth * 0.024,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF16A085),
                                  ),
                                ),
                              ],
                            ),
                            if (_members.length < _maxMemberCount)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _addNewMember,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: maxWidth * 0.02,
                                      vertical: maxHeight * 0.01,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A085)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF16A085),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          color: const Color(0xFF16A085),
                                          size: maxWidth * 0.018,
                                        ),
                                        SizedBox(width: maxWidth * 0.008),
                                        Text(
                                          "Ajouter",
                                          style: TextStyle(
                                            fontSize: maxWidth * 0.016,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF16A085),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: maxHeight * 0.03),

                        // Liste des membres avec scroll
                        Expanded(
                          child: _members.isEmpty
                              ? Center(
                                  child: Text(
                                    "Aucun membre ajouté",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.018,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _members.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: maxHeight * 0.02),
                                  itemBuilder: (context, index) =>
                                      _buildTabletMemberCard(index,
                                          _members[index], maxWidth, maxHeight),
                                ),
                        ),

                        SizedBox(height: maxHeight * 0.02),

                        // Boutons d'action
                        Column(
                          children: [
                            // Bouton pour sauvegarder sans quitter
                            if (_members.length >
                                1) // Afficher seulement s'il y a des membres ajoutés
                              Container(
                                width: double.infinity,
                                margin:
                                    EdgeInsets.only(bottom: maxHeight * 0.015),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _saveMembers,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: maxWidth * 0.04,
                                        vertical: maxHeight * 0.015,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      "SAUVEGARDER",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: maxWidth * 0.018,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Boutons principaux
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => context.go('/home'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: maxWidth * 0.03,
                                      vertical: maxHeight * 0.015,
                                    ),
                                  ),
                                  child: Text(
                                    "PASSER",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: maxWidth * 0.016,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF16A085)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _finishAndGoHome,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A085),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: maxWidth * 0.04,
                                        vertical: maxHeight * 0.015,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      "TERMINER",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: maxWidth * 0.018,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletMemberCard(
      int index, MAMMember member, double maxWidth, double maxHeight) {
    final bool isFounder = member.isFounder;

    return Container(
      decoration: BoxDecoration(
        color: isFounder
            ? const Color(0xFF16A085).withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFounder
              ? const Color(0xFF16A085).withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(maxWidth * 0.025),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la carte membre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(maxWidth * 0.008),
                      decoration: BoxDecoration(
                        color: isFounder
                            ? const Color(0xFF16A085)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFounder ? Icons.star : Icons.person,
                        color: Colors.white,
                        size: maxWidth * 0.015,
                      ),
                    ),
                    SizedBox(width: maxWidth * 0.015),
                    Text(
                      isFounder ? "Fondateur" : "Membre ${index + 1}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: maxWidth * 0.018,
                        color: isFounder
                            ? const Color(0xFF16A085)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (!isFounder)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeMember(index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(maxWidth * 0.008),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade400,
                          size: maxWidth * 0.018,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: maxHeight * 0.02),

            // Formulaire en ligne pour iPad
            Row(
              children: [
                // Prénom
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Prénom",
                        style: TextStyle(
                          fontSize: maxWidth * 0.014,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: maxHeight * 0.008),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: TextField(
                          enabled: !isFounder,
                          controller:
                              TextEditingController(text: member.firstName),
                          onChanged: (value) => member.firstName = value,
                          style: TextStyle(fontSize: maxWidth * 0.016),
                          decoration: InputDecoration(
                            hintText: isFounder
                                ? member.firstName
                                : "Entrez le prénom",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                isFounder ? Colors.grey.shade100 : Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: maxWidth * 0.015,
                              vertical: maxHeight * 0.015,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: maxWidth * 0.02),

                // Nom
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nom",
                        style: TextStyle(
                          fontSize: maxWidth * 0.014,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: maxHeight * 0.008),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: TextField(
                          enabled: !isFounder,
                          controller:
                              TextEditingController(text: member.lastName),
                          onChanged: (value) => member.lastName = value,
                          style: TextStyle(fontSize: maxWidth * 0.016),
                          decoration: InputDecoration(
                            hintText:
                                isFounder ? member.lastName : "Entrez le nom",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                isFounder ? Colors.grey.shade100 : Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: maxWidth * 0.015,
                              vertical: maxHeight * 0.015,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: maxWidth * 0.02),

                // Email
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Email",
                        style: TextStyle(
                          fontSize: maxWidth * 0.014,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: maxHeight * 0.008),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: TextField(
                          enabled: !isFounder,
                          controller: TextEditingController(text: member.email),
                          onChanged: (value) => member.email = value,
                          style: TextStyle(fontSize: maxWidth * 0.016),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: "Entrez l'adresse email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                isFounder ? Colors.grey.shade100 : Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: maxWidth * 0.015,
                              vertical: maxHeight * 0.015,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Construire une carte pour un membre
  Widget _buildMemberCard(int index, MAMMember member) {
    final bool isFounder = member.isFounder;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Membre ${index + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFounder ? const Color(0xFF16A085) : Colors.black87,
                  ),
                ),
                if (!isFounder)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeMember(index),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Champs pour le prénom
            TextField(
              enabled: !isFounder,
              controller: TextEditingController(text: member.firstName),
              onChanged: (value) => member.firstName = value,
              decoration: InputDecoration(
                labelText: isFounder ? member.firstName : "Prénom",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: isFounder,
                fillColor: isFounder ? Colors.grey[200] : null,
              ),
            ),
            const SizedBox(height: 8),

            // Champs pour le nom
            TextField(
              enabled: !isFounder,
              controller: TextEditingController(text: member.lastName),
              onChanged: (value) => member.lastName = value,
              decoration: InputDecoration(
                labelText: isFounder ? member.lastName : "Nom",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: isFounder,
                fillColor: isFounder ? Colors.grey[200] : null,
              ),
            ),
            const SizedBox(height: 8),

            // Champs pour l'email
            TextField(
              enabled: !isFounder,
              controller: TextEditingController(text: member.email),
              onChanged: (value) => member.email = value,
              decoration: InputDecoration(
                labelText: "Email",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: isFounder,
                fillColor: isFounder ? Colors.grey[200] : null,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }
}

// Classe pour représenter un membre de la MAM
class MAMMember {
  String firstName;
  String lastName;
  String email;
  final bool isFounder;

  MAMMember({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isFounder,
  });
}
