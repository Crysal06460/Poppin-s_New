import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/message_badge_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExchangesScreen extends StatefulWidget {
  const ExchangesScreen({Key? key}) : super(key: key);

  @override
  _ExchangesScreenState createState() => _ExchangesScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ExchangesScreenState extends State<ExchangesScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  String? selectedChildId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploadingFile = false;
  int _selectedIndex = 1;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        throw Exception('Utilisateur non connecté');
      }

      // Récupérer l'email de l'utilisateur actuel
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Vérifier si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      // ID de structure à utiliser (par défaut, utiliser l'ID de l'utilisateur)
      String structureId = user.uid;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Échanges: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // Récupérer la structure pour déterminer le type
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        setState(() {
          structureName =
              structureDoc.data()?['structureName'] ?? 'Structure inconnue';
        });
      }

      final String structureType = structureDoc.exists
          ? (structureDoc.data()?['structureType'] ?? "AssistanteMaternelle")
          : "AssistanteMaternelle";

      // Récupérer tous les enfants de la structure
      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = childrenSnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      // Appliquer le filtrage selon le type de structure (MAM ou AssistanteMaternelle)
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == "MAM") {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
          return assignedEmail == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 Échanges: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Échanges: Assistante Maternelle - affichage de tous les enfants");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      final List<Map<String, dynamic>> loadedEnfants = [];
      for (var child in filteredChildren) {
        if (child['schedule']?[capitalizedWeekday] != null) {
          loadedEnfants.add({
            'id': child['id'],
            'prenom': child['firstName'] ?? 'Sans nom',
            'genre': child['gender'] ?? 'Non spécifié',
            'photoUrl': child['photoUrl'] ?? '',
            'parentId': child['parentId'] ?? '',
            'discussionEnCours': child['discussionEnCours'] ?? false,
            'structureId': structureId,
          });
        }
      }

      setState(() {
        enfants = loadedEnfants;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
      if (mounted) {
        _showErrorSnackBar("Erreur lors du chargement des données");
      }
    }
  }

  void _showErrorSnackBar(String message, {BuildContext? dialogContext}) {
    final context = dialogContext ?? this.context;
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Future<void> _debugChildAndParentInfo(String childId) async {
    try {
      print("\n===== DÉBOGAGE RELATION PARENT-ENFANT =====");

      // 1. Obtenir la structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      print("🔍 Enfant: $childId, Structure: $structureId");

      // 2. Récupérer le document de l'enfant
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .get();

      print("🧒 Document enfant existe: ${childDoc.exists}");

      if (childDoc.exists) {
        final data = childDoc.data()!;
        print("🧒 Données de l'enfant:");
        data.forEach((key, value) {
          print("   - $key: $value");
        });

        // Vérifier si parentId existe
        final parentId = data['parentId'];
        print("👨‍👩‍👧 parentId dans le document enfant: $parentId");

        // Tenter de trouver les parents dans users
        print("\n🔍 Recherche dans la collection users par childId...");
        final parentQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('children', arrayContains: childId)
            .get();

        print("👪 Parents trouvés: ${parentQuery.docs.length}");

        for (var doc in parentQuery.docs) {
          print("📝 Document parent ID: ${doc.id}");
          final parentData = doc.data();
          print("   - uid: ${parentData['uid']}");
          print("   - email: ${parentData['email']}");
          print(
              "   - name: ${parentData['firstName']} ${parentData['lastName']}");
          print("   - children: ${parentData['children']}");
        }
      }

      print("===== FIN DÉBOGAGE =====\n");
    } catch (e) {
      print("❌ Erreur débogage: $e");
    }
  }

// Méthode pour afficher un message d'avertissement
  void _showMessageSentWithWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message envoyé (notification parent non confirmée)'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message, BuildContext context) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  Future<void> _forceShowBadgeForChild(String childId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentUserEmail = user.email?.toLowerCase();
      if (currentUserEmail == null) return;

      // Récupérer l'enfant dans la liste locale
      final enfant = enfants.firstWhere(
        (e) => e['id'] == childId,
        orElse: () => <String, dynamic>{},
      );
      if (enfant.isEmpty) return;

      final String structureId = enfant['structureId'] ?? user.uid;

      // Récupérer le document de l'enfant pour vérifier assignedMemberEmail
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .get();

      if (!childDoc.exists) return;

      final childData = childDoc.data()!;
      final String? assignedMemberEmail =
          childData['assignedMemberEmail']?.toString().toLowerCase();

      // Vérifier si c'est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final bool isMamMember = userData['role'] == 'mamMember';

      if (isMamMember) {
        // Si c'est un membre MAM, vérifier si l'enfant lui est assigné
        if (assignedMemberEmail != null && assignedMemberEmail.isNotEmpty) {
          if (assignedMemberEmail == currentUserEmail) {
            // Mise à jour pour le membre assigné
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_unread_messages', true);

            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserEmail)
                .update({'unreadMessages': FieldValue.increment(1)});

            print(
                "✅ Badge forcé pour le membre MAM assigné: $currentUserEmail");
          } else {
            print(
                "⚠️ Badge non forcé: enfant assigné à $assignedMemberEmail, utilisateur actuel: $currentUserEmail");
          }
        }
      } else {
        // Pour une assistante maternelle individuelle
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_unread_messages', true);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserEmail)
            .update({'unreadMessages': FieldValue.increment(1)});

        print(
            "✅ Badge forcé pour l'assistante individuelle: $currentUserEmail");
      }
    } catch (e) {
      print("❌ Erreur lors du forçage du badge: $e");
    }
  }

  Future<void> _pickAndSendFile(
      String childId, BuildContext dialogContext) async {
    try {
      setState(() => _isUploadingFile = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingFile = false);
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Fichier non valide');
      }

      // Vérifier la taille (10MB max)
      if (file.size > 10 * 1024 * 1024) {
        throw Exception('Le fichier est trop volumineux (maximum 10MB)');
      }

      final fileName = file.name;
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        throw Exception('Non connecté');
      }

      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId = enfant['structureId'] ?? userId;

      // Récupérer l'ID parent de l'enfant
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .get();

      final childData = childDoc.data();
      final parentId = childData?['parentId'];

      // Créer le chemin du fichier
      final storagePath = 'exchanges/$userId/$timestamp-$fileName';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      // Upload avec metadata
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'userId': userId,
          'childId': childId,
          'originalName': fileName,
        },
      );

      // Faire l'upload
      final uploadTask = storageRef.putData(file.bytes!, metadata);

      // Attendre la fin de l'upload
      await uploadTask.whenComplete(() => null);
      final downloadUrl = await storageRef.getDownloadURL();

      // Créer le message dans Firestore
      await FirebaseFirestore.instance.collection('exchanges').add({
        'childId': childId,
        'senderId': userId,
        'type': 'file',
        'fileName': fileName,
        'fileUrl': downloadUrl,
        'fileType': mimeType,
        'fileSize': file.size,
        'timestamp': FieldValue.serverTimestamp(),
        'senderType': 'assistante',
        'nonLu': true,
        'parentId': parentId, // Ajouter l'ID du parent
      });

      // Notification explicite des nouveaux messages
      if (parentId != null) {
        try {
          // Récupérer le document de l'utilisateur parent
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: parentId)
              .limit(1)
              .get();

          if (userDoc.docs.isNotEmpty) {
            final parentEmail = userDoc.docs.first.id;
            // Mettre à jour un compteur de messages non lus
            await FirebaseFirestore.instance
                .collection('users')
                .doc(parentEmail)
                .update({'unreadMessages': FieldValue.increment(1)});
          }
        } catch (e) {
          print("Erreur lors de la notification du parent: $e");
        }
      }

      setState(() => _isUploadingFile = false);

      if (dialogContext.mounted) {
        _showSuccessSnackBar('Fichier envoyé avec succès', dialogContext);
      }
    } catch (e) {
      print('Erreur upload: $e');
      setState(() => _isUploadingFile = false);

      if (dialogContext.mounted) {
        _showErrorSnackBar(
            e.toString().contains('Exception:')
                ? e.toString().split('Exception: ')[1]
                : "Erreur lors de l'envoi du fichier",
            dialogContext: dialogContext);
      }
    }
  }

  Future<void> _sendMessage(String childId, BuildContext dialogContext) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }

    // Déboguer avant d'envoyer
    await _debugChildAndParentInfo(childId);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Vous devez être connecté',
            dialogContext: dialogContext);
        return;
      }

      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId = enfant['structureId'] ?? user.uid;

      // Vérification d'une éventuelle réponse à un message
      final replyToId = messageText.split(': ')[0].startsWith('@')
          ? messageText.split(': ')[0].substring(1)
          : null;
      final messageContent =
          replyToId != null ? messageText.split(': ')[1] : messageText;

      // MÉTHODE 1: Récupérer le parentId à partir du document enfant
      var parentId;
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .get();

      if (childDoc.exists) {
        final childData = childDoc.data();
        parentId = childData?['parentId'];

        // MÉTHODE 2: Si parentId est manquant, chercher dans la collection users
        if (parentId == null || parentId.isEmpty) {
          print(
              "🔍 parentId manquant dans le document enfant, recherche alternative...");

          final parentUsers = await FirebaseFirestore.instance
              .collection('users')
              .where('children', arrayContains: childId)
              .limit(1)
              .get();

          if (parentUsers.docs.isNotEmpty) {
            final parentUser = parentUsers.docs.first;
            parentId = parentUser.data()['uid'];
            print("✅ parentId trouvé via la collection users: $parentId");

            // Mettre à jour l'enfant avec le parentId pour la prochaine fois
            try {
              await FirebaseFirestore.instance
                  .collection('structures')
                  .doc(structureId)
                  .collection('children')
                  .doc(childId)
                  .update({'parentId': parentId});

              print("✅ Document enfant mis à jour avec parentId: $parentId");
            } catch (e) {
              print("❌ Erreur lors de la mise à jour du document enfant: $e");
            }
          }

          // MÉTHODE 3: Chercher par l'ID de l'enfant s'il correspond à un email
          if ((parentId == null || parentId.isEmpty) && childId.contains('@')) {
            try {
              final parentUserDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(childId.toLowerCase())
                  .get();

              if (parentUserDoc.exists) {
                parentId = parentUserDoc.data()?['uid'];
                print(
                    "✅ parentId trouvé via l'ID de l'enfant (email): $parentId");
              }
            } catch (e) {
              print("❌ Erreur lors de la recherche par email: $e");
            }
          }
        }
      }

      // Trouver l'email du membre assigné à l'enfant
      try {
        if (childDoc.exists) {
          final childData = childDoc.data();
          final String? assignedMemberEmail =
              childData?['assignedMemberEmail']?.toString().toLowerCase();

          if (assignedMemberEmail != null && assignedMemberEmail.isNotEmpty) {
            // Si l'enfant est assigné à un membre, forcer le badge uniquement pour ce membre
            print(
                "✉️ Nouveau message pour enfant assigné à: $assignedMemberEmail");

            // Mettre à jour le compteur unreadMessages du membre assigné
            await FirebaseFirestore.instance
                .collection('users')
                .doc(assignedMemberEmail)
                .update({'unreadMessages': FieldValue.increment(1)});

            // Si ce message n'est pas envoyé par vous, alors forcer le badge
            if (user.email?.toLowerCase() != assignedMemberEmail) {
              print(
                  "🔔 Notification sera envoyée uniquement à: $assignedMemberEmail");
            } else {
              // Pour vous-même, mettre à jour les préférences locales
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_unread_messages', true);
            }
          } else {
            // Si l'enfant n'est assigné à aucun membre spécifique (cas d'une assistante maternelle individuelle)
            print(
                "🔔 Enfant non assigné à un membre spécifique, notification standard");
            await _forceShowBadgeForChild(childId);
          }
        } else {
          // Document de l'enfant non trouvé, utiliser méthode standard
          print("⚠️ Document enfant non trouvé, notification standard");
          await MessageBadgeUtil.forceShowBadge(childId);
        }
      } catch (e) {
        print(
            "❌ Erreur lors de la notification: $e - Notification standard utilisée");
        await MessageBadgeUtil.forceShowBadge(childId);
      }

      // Créer les données du message
      final messageData = {
        'childId': childId,
        'senderId': user.uid,
        'content': messageContent,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'senderType': 'assistante',
        'nonLu': true,
        'replyTo': replyToId,
      };

      // Ajouter le parentId si trouvé
      if (parentId != null && parentId.isNotEmpty) {
        messageData['parentId'] = parentId;
      }

      // ÉTAPE CRITIQUE: Ajouter le message à Firestore
      final messageRef = await FirebaseFirestore.instance
          .collection('exchanges')
          .add(messageData);

      _messageController.clear();
      print("✅ Message envoyé avec ID: ${messageRef.id}");

      // NOTIFICATION: Si nous avons trouvé un parentId, mettre à jour le compteur de messages non lus
      if (parentId != null && parentId.isNotEmpty) {
        try {
          // Trouver l'email du parent via son ID
          final parentUserQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: parentId)
              .limit(1)
              .get();

          String? parentEmail;
          if (parentUserQuery.docs.isNotEmpty) {
            parentEmail = parentUserQuery.docs.first.id;
            print("📧 Email du parent trouvé: $parentEmail");
          } else {
            // Deuxième tentative: chercher par l'ID directement (si c'est un email)
            if (parentId.contains('@')) {
              parentEmail = parentId.toLowerCase();
              print("📧 Email du parent utilisé directement: $parentEmail");
            }
          }

          // Si nous avons un email, mettre à jour le compteur
          if (parentEmail != null && parentEmail.isNotEmpty) {
            final parentDocRef =
                FirebaseFirestore.instance.collection('users').doc(parentEmail);

            final parentDoc = await parentDocRef.get();

            if (parentDoc.exists) {
              // Mise à jour du compteur de messages non lus
              await parentDocRef
                  .update({'unreadMessages': FieldValue.increment(1)});
              print(
                  "✅ Compteur de messages non lus mis à jour pour: $parentEmail");
            } else {
              // Créer le document avec un compteur initial
              await parentDocRef.set({'unreadMessages': 1, 'uid': parentId},
                  SetOptions(merge: true));
              print("✅ Document créé avec compteur initial pour: $parentEmail");
            }

            // Message de succès avec confirmation
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text('Message envoyé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            print("⚠️ Email du parent non trouvé pour l'UID: $parentId");
            _showMessageSentWithWarning(dialogContext);
          }
        } catch (e) {
          print("❌ Erreur lors de l'envoi de la notification: $e");
          _showMessageSentWithWarning(dialogContext);
        }
      } else {
        print("⚠️ parentId manquant, impossible d'envoyer une notification");

        // Malgré l'absence de parentId, tentons d'envoyer des notifications
        try {
          // Chercher les parents qui ont cet enfant dans leur liste
          final parentUsers = await FirebaseFirestore.instance
              .collection('users')
              .where('children', arrayContains: childId)
              .get();

          if (parentUsers.docs.isNotEmpty) {
            for (var doc in parentUsers.docs) {
              // Mettre à jour le compteur pour chaque parent trouvé
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(doc.id)
                  .update({'unreadMessages': FieldValue.increment(1)});

              print("✅ Compteur mis à jour pour parent: ${doc.id}");
            }

            // Le message a été envoyé avec succès
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text('Message envoyé avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            // Si aucun parent n'a été trouvé, afficher l'avertissement
            _showMessageSentWithWarning(dialogContext);
          }
        } catch (e) {
          print("❌ Erreur lors de la tentative d'envoi alternatif: $e");
          _showMessageSentWithWarning(dialogContext);
        }
      }
    } catch (error) {
      print("❌ Erreur lors de l'envoi du message: $error");
      if (dialogContext.mounted) {
        _showErrorSnackBar("Erreur lors de l'envoi du message",
            dialogContext: dialogContext);
      }
    }
  }

// Ajouter cette méthode d'affichage de message

// Ajouter cette méthode auxiliaire
  void _handleMessageSentWithWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message envoyé (notification parent non confirmée)'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _replyToMessage(String messageId) async {
    final message = await FirebaseFirestore.instance
        .collection('exchanges')
        .doc(messageId)
        .get();
    final messageData = message.data() as Map<String, dynamic>?;

    if (messageData != null) {
      _messageController.text = '@${messageData['senderId']}: ';
      _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length));
    }
  }

  Future<void> _toggleReaction(String messageId, String reaction) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final message = await FirebaseFirestore.instance
        .collection('exchanges')
        .doc(messageId)
        .get();
    final messageData = message.data() as Map<String, dynamic>?;

    if (userId != null && messageData != null) {
      final reactions = messageData['reactions'] as Map<String, dynamic>? ?? {};
      final userReaction = reactions[reaction] as List<dynamic>?;

      if (userReaction?.contains(userId) == true) {
        await FirebaseFirestore.instance
            .collection('exchanges')
            .doc(messageId)
            .update({
          'reactions.$reaction': FieldValue.arrayRemove([userId])
        });
      } else {
        await FirebaseFirestore.instance
            .collection('exchanges')
            .doc(messageId)
            .set({
          'reactions.$reaction': FieldValue.arrayUnion([userId])
        }, SetOptions(merge: true));
      }
    }
  }

  Widget _buildMessage(
      Map<String, dynamic> messageData, bool isMe, bool isTablet) {
    final timestamp = messageData['timestamp'] as Timestamp?;
    final formattedTime =
        timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    return Container(
      margin: EdgeInsets.symmetric(vertical: isTablet ? 6 : 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Bouton répondre
          TextButton(
            onPressed: () => _replyToMessage(messageData['id']),
            child: Text(
              'Répondre',
              style: TextStyle(
                color: primaryBlue,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
          // Message
          Container(
            margin: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width *
                    (isTablet ? 0.6 : 0.75)),
            decoration: BoxDecoration(
              color: isMe ? primaryBlue.withOpacity(0.1) : lightBlue,
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: isTablet ? 6 : 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: messageData['type'] == 'file'
                ? _buildFileMessageForTablet(messageData, isTablet)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Réponse à un message
                      if (messageData['replyTo'] != null)
                        Container(
                          margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 8,
                            vertical: isTablet ? 6 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? primaryBlue.withOpacity(0.2)
                                : Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(isTablet ? 12 : 8),
                          ),
                          child: Text(
                            messageData['replyTo'],
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: isTablet ? 16 : 14,
                            ),
                          ),
                        ),
                      Text(
                        messageData['content'] ?? '',
                        style: TextStyle(
                          color: isMe ? primaryBlue : Colors.black87,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                      SizedBox(height: isTablet ? 8 : 4),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isTablet ? 12 : 10,
                        ),
                      ),
                    ],
                  ),
          ),
          // Réactions
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // Bouton like
              IconButton(
                onPressed: () => _toggleReaction(messageData['id'], 'like'),
                icon: Icon(
                  Icons.thumb_up,
                  color: primaryBlue,
                  size: isTablet ? 22 : 18,
                ),
              ),
              // Décompte des likes
              Text(
                '${messageData['reactions']?['like']?.length ?? 0} 👍',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessageForTablet(
      Map<String, dynamic> message, bool isTablet) {
    final fileType = message['fileType'] ?? '';
    final isImage = fileType.startsWith('image/');
    final timestamp = message['timestamp'] as Timestamp?;
    final formattedTime =
        timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    Future<void> _openFile() async {
      try {
        final fileUrl = message['fileUrl'];
        if (fileUrl == null) {
          throw 'URL du fichier non disponible';
        }

        if (kIsWeb) {
          // Utilisez url_launcher pour ouvrir l'URL
          if (await canLaunchUrlString(fileUrl)) {
            await launchUrlString(fileUrl);
          } else {
            throw 'Impossible d\'ouvrir le fichier';
          }
        } else {
          // Pour mobile, utilisez également url_launcher
          if (await canLaunchUrlString(fileUrl)) {
            await launchUrlString(fileUrl);
          } else {
            throw 'Impossible d\'ouvrir le fichier';
          }
        }
      } catch (e) {
        print('Erreur lors de l\'ouverture du fichier: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: primaryRed,
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openFile,
            borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 12 : 8),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image : Icons.insert_drive_file,
                    color: primaryBlue,
                    size: isTablet ? 26 : 22,
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Expanded(
                    child: Text(
                      message['fileName'] ?? 'Fichier',
                      style: TextStyle(
                        color: primaryBlue,
                        decoration: TextDecoration.underline,
                        fontSize: isTablet ? 16 : 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isImage && message['fileUrl'] != null) ...[
          SizedBox(height: isTablet ? 12 : 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
            child: Image.network(
              message['fileUrl'],
              width: isTablet ? 250 : 200,
              height: isTablet ? 250 : 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: isTablet ? 250 : 200,
                  height: isTablet ? 180 : 150,
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: isTablet ? 48 : 40,
                  ),
                );
              },
            ),
          ),
        ],
        SizedBox(height: isTablet ? 8 : 4),
        Text(
          formattedTime,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: isTablet ? 12 : 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> message) {
    final fileType = message['fileType'] ?? '';
    final isImage = fileType.startsWith('image/');
    final timestamp = message['timestamp'] as Timestamp?;
    final formattedTime =
        timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    Future<void> _openFile() async {
      try {
        final fileUrl = message['fileUrl'];
        if (fileUrl == null) {
          throw 'URL du fichier non disponible';
        }

        if (kIsWeb) {
          // Utilisez url_launcher pour ouvrir l'URL
          if (await canLaunchUrlString(fileUrl)) {
            await launchUrlString(fileUrl);
          } else {
            throw 'Impossible d\'ouvrir le fichier';
          }
        } else {
          // Pour mobile, utilisez également url_launcher
          if (await canLaunchUrlString(fileUrl)) {
            await launchUrlString(fileUrl);
          } else {
            throw 'Impossible d\'ouvrir le fichier';
          }
        }
      } catch (e) {
        print('Erreur lors de l\'ouverture du fichier: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: primaryRed,
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openFile,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image : Icons.insert_drive_file,
                    color: primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message['fileName'] ?? 'Fichier',
                      style: TextStyle(
                        color: primaryBlue,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isImage && message['fileUrl'] != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              message['fileUrl'],
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          formattedTime,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _showChatPopup(Map<String, dynamic> enfant) {
    // Utiliser l'ID de structure stocké avec l'enfant
    final String structureId =
        enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;
    final bool isTabletDevice = isTablet(context);

    FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(enfant['id'])
        .update({
      'discussionEnCours': true,
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(isTabletDevice ? 24 : 16),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(dialogContext).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(enfant['photoUrl'] ?? ''),
                        backgroundColor: lightBlue,
                        radius: isTabletDevice ? 36 : 30,
                        child: enfant['photoUrl'] == null ||
                                enfant['photoUrl'].isEmpty
                            ? Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 30 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: isTabletDevice ? 20 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Discussion avec ${enfant['prenom']}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTabletDevice ? 22 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Parent",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isTabletDevice ? 16 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: isTabletDevice ? 28 : 24,
                        ),
                        onPressed: () {
                          // Mettre à jour l'indicateur de discussion en cours
                          FirebaseFirestore.instance
                              .collection('structures')
                              .doc(structureId)
                              .collection('children')
                              .doc(enfant['id'])
                              .update({
                            'discussionEnCours': false,
                          });
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  ),
                ),

                // Messages
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('exchanges')
                        .where('childId', isEqualTo: enfant['id'])
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('Erreur de chargement: ${snapshot.error}');
                        return Center(
                          child: Text(
                            'Erreur de chargement des messages',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: isTabletDevice ? 16 : 14,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                            child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryBlue),
                        ));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: isTabletDevice ? 60 : 48,
                                    color: Colors.grey),
                                SizedBox(height: isTabletDevice ? 20 : 16),
                                Text(
                                  "Aucun message\nCommencez la conversation !",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: isTabletDevice ? 20 : 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final messages = snapshot.data!.docs;
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.only(
                          bottom: isTabletDevice ? 12 : 8,
                          left: isTabletDevice ? 12 : 0,
                          right: isTabletDevice ? 12 : 0,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageData = {
                            ...messages[index].data() as Map<String, dynamic>,
                            'id': messages[index].id,
                          };
                          final isMe = messageData['senderId'] ==
                              FirebaseAuth.instance.currentUser?.uid;
                          // Marquer le message comme lu
                          FirebaseFirestore.instance
                              .collection('exchanges')
                              .doc(messages[index].id)
                              .update({
                            'nonLu': false,
                          });
                          return _buildMessage(
                            messageData,
                            isMe,
                            isTabletDevice,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Upload Progress
                if (_isUploadingFile)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTabletDevice ? 24 : 16,
                    ),
                    child: LinearProgressIndicator(
                      backgroundColor: lightBlue,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  ),

                // Barre de saisie
                Container(
                  padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.attach_file,
                          size: isTabletDevice ? 28 : 24,
                        ),
                        color: primaryBlue,
                        onPressed: _isUploadingFile
                            ? null
                            : () =>
                                _pickAndSendFile(enfant['id'], dialogContext),
                      ),
                      SizedBox(width: isTabletDevice ? 12 : 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(
                            fontSize: isTabletDevice ? 16 : 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Écrire un message...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: primaryBlue,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isTabletDevice ? 24 : 20,
                              vertical: isTabletDevice ? 14 : 10,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onSubmitted: (_) =>
                              _sendMessage(enfant['id'], dialogContext),
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                      SizedBox(width: isTabletDevice ? 12 : 8),
                      CircleAvatar(
                        backgroundColor: primaryBlue,
                        radius: isTabletDevice ? 24 : 20,
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: isTabletDevice ? 24 : 20,
                          ),
                          onPressed: () =>
                              _sendMessage(enfant['id'], dialogContext),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      context.go('/child-info');
    }
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final isBoy = enfant['genre'] == 'Garçon';

    return GestureDetector(
      onTap: () => _showChatPopup(enfant),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isBoy
                          ? [primaryBlue.withOpacity(0.7), primaryBlue]
                          : [primaryRed.withOpacity(0.7), primaryRed],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isBoy ? primaryBlue : primaryRed).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                // Indicateur de messages non lus modifié
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('exchanges')
                      .where('childId', isEqualTo: enfant['id'])
                      .where('nonLu', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final nonLuCount = snapshot.data?.docs.length ?? 0;
                    if (nonLuCount > 0) {
                      return Positioned(
                        right: 0,
                        top: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryRed,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                nonLuCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Label "Messages non lus"
                            Container(
                              margin: EdgeInsets.only(top: 2, right: 4),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryRed.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Messages non lus",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isBoy ? primaryBlue : primaryRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Discussion avec le parent",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('exchanges')
                        .where('childId', isEqualTo: enfant['id'])
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "Aucun message",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      }

                      final lastMessage = snapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                      final isFile = lastMessage['type'] == 'file';

                      return Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          isFile
                              ? "📎 ${lastMessage['fileName'] ?? 'Fichier'}"
                              : lastMessage['content'] != null
                                  ? (lastMessage['content'].toString().length >
                                          30
                                      ? "${lastMessage['content'].toString().substring(0, 30)}..."
                                      : lastMessage['content'].toString())
                                  : "",
                          style: TextStyle(
                            fontSize: 12,
                            color: lastMessage['nonLu'] == true
                                ? Colors.black87
                                : Colors.grey.shade500,
                            fontWeight: lastMessage['nonLu'] == true
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                color: primaryBlue,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // État vide (aucun enfant)
  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Echanges.png',
            width: 100,
            height: 100,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: primaryBlue.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Aucun enfant prévu aujourd\'hui',
            style: TextStyle(
              fontSize: 18,
              color: primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Les échanges seront disponibles\nlorsque des enfants seront présents',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  )
                : enfants.isEmpty
                    ? _buildEmptyState()
                    : isTabletDevice
                        ? _buildTabletLayout()
                        : ListView.builder(
                            itemCount: enfants.length,
                            itemBuilder: _buildEnfantCard,
                          ),
          )
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

// Nouvelle méthode pour construire la mise en page en grille pour iPad
  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

// Nouvelle carte enfant optimisée pour iPad
  // Nouvelle carte enfant optimisée pour iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final isBoy = enfant['genre'] == 'Garçon';
    final avatarColor = isBoy ? primaryBlue : primaryRed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // En-tête avec gradient et infos enfant
              Container(
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar avec photo de l'enfant
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: enfant['photoUrl'] != null &&
                                enfant['photoUrl'].isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  enfant['photoUrl'],
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Text(
                                    enfant['prenom'][0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: avatarColor,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: avatarColor,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        enfant['prenom'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Zone centrale avec "Aucun message" ou dernier message
              Expanded(
                child: Center(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('exchanges')
                        .where('childId', isEqualTo: enfant['id'])
                        .where('nonLu', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final nonLuCount = snapshot.data?.docs.length ?? 0;
                      if (nonLuCount > 0) {
                        return Positioned(
                          right: 8,
                          top: 8,
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryRed,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  nonLuCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(top: 2),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryRed.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Messages non lus",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return SizedBox.shrink();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          // Bouton + pour ouvrir la discussion
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => _showChatPopup(enfant),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  color: avatarColor,
                  size: 24,
                ),
              ),
            ),
          ),

          // Indicateur de messages non lus
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('exchanges')
                .where('childId', isEqualTo: enfant['id'])
                .where('nonLu', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final nonLuCount = snapshot.data?.docs.length ?? 0;
              if (nonLuCount > 0) {
                return Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      nonLuCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              } else {
                return SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }

  // AppBar personnalisé avec gradient
  // AppBar personnalisé avec gradient adapté pour iPad
  Widget _buildAppBar(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryBlue,
            primaryBlue.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, isTabletDevice ? 24 : 16, 16, isTabletDevice ? 28 : 20),
          child: Column(
            children: [
              // Première ligne: nom structure et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName,
                      style: TextStyle(
                        fontSize: isTabletDevice ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isTabletDevice ? 16 : 12,
                        vertical: isTabletDevice ? 8 : 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: isTabletDevice ? 16 : 14,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTabletDevice ? 22 : 15),
              // Icône et titre de la page dans un conteneur bordé comme sur la page Activités
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isTabletDevice ? 22 : 16,
                    vertical: isTabletDevice ? 12 : 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white, width: isTabletDevice ? 2.5 : 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/Icone_Echanges.png',
                      width: isTabletDevice ? 36 : 30,
                      height: isTabletDevice ? 36 : 30,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.chat_bubble_outline,
                        size: isTabletDevice ? 32 : 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isTabletDevice ? 12 : 8),
                    Text(
                      'Échanges',
                      style: TextStyle(
                        fontSize: isTabletDevice ? 24 : 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation du bas
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryBlue,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Dashboard.png',
            width: 60,
            height: 60,
          ),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/maison_icon.png',
            width: 60,
            height: 60,
          ),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Ajout_Enfant.png',
            width: 60,
            height: 60,
          ),
          label: "Ajouter",
        ),
      ],
    );
  }
}
