import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class MAMMemberRemovalScreen extends StatefulWidget {
  const MAMMemberRemovalScreen({Key? key}) : super(key: key);

  @override
  _MAMMemberRemovalScreenState createState() => _MAMMemberRemovalScreenState();
}

class _MAMMemberRemovalScreenState extends State<MAMMemberRemovalScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> members = [];

  // Définition des couleurs de la palette
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier d'abord si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si l'utilisateur est membre d'une MAM, récupérer l'ID de la structure
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur (cas d'un propriétaire de structure)
    return user.uid;
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        throw Exception("Impossible de déterminer la structure");
      }

      print("⬇️ Chargement des membres pour la structure: $structureId");

      // Récupérer les membres de la MAM
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .get();

      print(
          "📊 Nombre de documents membres trouvés: ${membersSnapshot.docs.length}");

      // Récupérer l'utilisateur actuel
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserEmail = currentUser?.email?.toLowerCase() ?? '';

      print("👤 Utilisateur actuel: $currentUserEmail");

      // Convertir les documents en liste de maps
      List<Map<String, dynamic>> tempMembers = [];

      // DEBUG - Afficher tous les documents pour comprendre ce qui est récupéré
      for (var doc in membersSnapshot.docs) {
        print("📄 Document trouvé - ID: ${doc.id}");
        print("📄 Contenu: ${doc.data()}");
      }

      for (var doc in membersSnapshot.docs) {
        final data = doc.data();

        // CORRECTION: Vérifier l'email de manière plus robuste
        final String memberEmail =
            data['email']?.toString().toLowerCase() ?? '';

        print("🔍 Membre analysé - ID: ${doc.id}, Email: $memberEmail");

        // CORRECTION: Une seule condition pour ajouter les membres
        if (memberEmail.isNotEmpty) {
          final bool isSelf = memberEmail == currentUserEmail;
          tempMembers.add({
            'id': doc.id,
            'email': memberEmail,
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'joinedAt': data['joinedAt'],
            'isSelf':
                isSelf, // Indicateur pour savoir si c'est l'utilisateur actuel
          });
          print(
              "✅ Membre ajouté à la liste: $memberEmail (${data['firstName']} ${data['lastName']})" +
                  (isSelf ? " (utilisateur actuel)" : ""));
        } else if (memberEmail.isEmpty) {
          // Si l'email est vide, essayer d'ajouter quand même si on a d'autres infos utiles
          if (data['firstName'] != null && data['lastName'] != null) {
            tempMembers.add({
              'id': doc.id,
              'email': 'non spécifié',
              'firstName': data['firstName'] ?? '',
              'lastName': data['lastName'] ?? '',
              'joinedAt': data['joinedAt'],
              'isSelf':
                  false, // Un membre sans email ne peut pas être l'utilisateur actuel
            });
            print(
                "⚠️ Membre ajouté sans email: ${data['firstName']} ${data['lastName']}");
          } else {
            print(
                "⚠️ Membre ignoré (informations insuffisantes) - ID: ${doc.id}");
          }
        }
      }

      print("📋 Nombre total de membres à afficher: ${tempMembers.length}");

      setState(() {
        members = tempMembers;
        isLoading = false;
      });
    } catch (e) {
      print("🚨 Erreur lors du chargement des membres: $e");
      setState(() {
        errorMessage = "Erreur lors du chargement des membres: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  void _showRemoveConfirmation(Map<String, dynamic> member) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "⚠️ Confirmation de suppression",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryRed,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Vous êtes sur le point de supprimer définitivement le membre:",
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "${member['firstName']} ${member['lastName']}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      member['email'],
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryRed.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: primaryRed,
                      size: 28,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "ATTENTION : Cette action est définitive et ne pourra pas être annulée. Toutes les données associées à ce membre seront effacées définitivement.",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeMember(member);
              },
              child: Text(
                "CONFIRMER",
                style: TextStyle(
                  color: primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        throw Exception("Impossible de déterminer la structure");
      }

      print(
          "🗑️ Suppression du membre - ID: ${member['id']}, Email: ${member['email']}");

      // Supprimer le membre de la collection members de la structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .doc(member['id'])
          .delete();

      print("✅ Membre supprimé de la collection members");

      // Supprimer l'utilisateur de la collection users s'il existe
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(member['email'])
            .get();

        if (userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(member['email'])
              .delete();
          print("✅ Utilisateur supprimé de la collection users");
        } else {
          print("⚠️ Utilisateur non trouvé dans la collection users");
        }
      } catch (e) {
        print("⚠️ Erreur lors de la suppression de l'utilisateur: $e");
        // Ne pas faire échouer l'opération si cette partie échoue
      }

      // Si c'était le dernier membre, mettre à jour la structure
      final remainingMembers = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .get();

      print("📊 Membres restants: ${remainingMembers.docs.length}");

      if (remainingMembers.docs.isEmpty) {
        // Si plus de membres, mettre à jour le type de structure en AssistanteMaternelle
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .update({
          'structureType': 'AssistanteMaternelle',
          'maxMemberCount': 1,
        });
        print("✅ Structure mise à jour en AssistanteMaternelle");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Le membre a été supprimé avec succès"),
          backgroundColor: Colors.green,
        ),
      );

      // Recharger la liste des membres
      _loadMembers();
    } catch (e) {
      print("🚨 Erreur lors de la suppression du membre: $e");
      setState(() {
        errorMessage =
            "Erreur lors de la suppression du membre: ${e.toString()}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Retrait d'un membre"),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(color: primaryBlue),
              )
            : Column(
                children: [
                  // En-tête explicatif
                  Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightBlue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: lightBlue),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: primaryBlue,
                          size: 28,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Cette page vous permet de supprimer un membre de votre MAM. "
                          "Cette action est définitive et supprimera toutes les données associées à ce membre.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Message d'erreur
                  if (errorMessage.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Nombre de membres
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Membres trouvés: ${members.length}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // Liste vide
                  if (members.isEmpty && !isLoading)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_outlined,
                              size: 60,
                              color: Colors.grey.withOpacity(0.7),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Aucun membre à afficher",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Liste des membres
                  if (members.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];

                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: primaryBlue.withOpacity(0.2),
                                child: Text(
                                  "${member['firstName'].isNotEmpty ? member['firstName'][0] : '?'}${member['lastName'].isNotEmpty ? member['lastName'][0] : '?'}",
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${member['firstName']} ${member['lastName']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Email: ${member['email']}",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    "ID: ${member['id']}",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () =>
                                    _showRemoveConfirmation(member),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryRed,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  "Supprimer",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
