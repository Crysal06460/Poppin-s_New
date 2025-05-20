import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/badged_icon.dart';
import '../utils/stock_badge_util.dart';
import '../utils/message_badge_util.dart';

class ParentMessagesScreen extends StatefulWidget {
  final String?
      childId; // Optionnel, si on veut afficher les messages pour un enfant spécifique

  const ParentMessagesScreen({Key? key, this.childId}) : super(key: key);

  @override
  _ParentMessagesScreenState createState() => _ParentMessagesScreenState();
}

class _ParentMessagesScreenState extends State<ParentMessagesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _selectedChild;
  bool _isLoading = true;
  bool _showStockBadge = false;
  bool _showMessageBadge = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadUserData();
    });
    _checkStockBadge();
    _checkMessageBadge();

    // Réinitialiser le badge des messages puisque nous sommes sur l'écran des messages
    MessageBadgeUtil.resetBadge();

    // S'assurer que le champ unreadMessages existe dans le document utilisateur
    final user = _auth.currentUser;
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get()
          .then((doc) {
        if (doc.exists) {
          final data = doc.data();
          if (data != null && !data.containsKey('unreadMessages')) {
            // Créer le champ s'il n'existe pas
            _firestore
                .collection('users')
                .doc(user.email?.toLowerCase())
                .update({'unreadMessages': 0});
          }
        }
      });
    }
  }

  Future<void> _checkStockBadge() async {
    final shouldShow = await StockBadgeUtil.shouldShowBadge();
    if (mounted) {
      setState(() {
        _showStockBadge = shouldShow;
      });
    }
  }

  Future<void> _checkMessageBadge() async {
    final shouldShow = await MessageBadgeUtil.shouldShowBadge();
    if (mounted) {
      setState(() {
        _showMessageBadge = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }

      // Récupérer les informations du parent
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final childIds = List<String>.from(userData['children'] ?? []);
        final structureId = userData['structureId'];

        if (childIds.isNotEmpty && structureId != null) {
          List<Map<String, dynamic>> childrenData = [];

          for (final childId in childIds) {
            final childDoc = await _firestore
                .collection('structures')
                .doc(structureId)
                .collection('children')
                .doc(childId)
                .get();

            if (childDoc.exists) {
              final data = childDoc.data()!;
              childrenData.add({
                'id': childDoc.id,
                'firstName': data['firstName'] ?? 'Sans nom',
                'lastName': data['lastName'] ?? '',
                'photoUrl': data['photoUrl'],
                'structureId': structureId,
                'gender': data['gender'] ?? 'Non spécifié',
              });
            }
          }

          setState(() {
            _children = childrenData;

            // Si un ID d'enfant est spécifié, sélectionner cet enfant
            if (widget.childId != null &&
                widget.childId!.isNotEmpty &&
                childrenData.isNotEmpty) {
              _selectedChild = childrenData.firstWhere(
                (child) => child['id'] == widget.childId,
                orElse: () => childrenData.first,
              );
            } else if (childrenData.isNotEmpty) {
              _selectedChild = childrenData.first;
            } else {
              _selectedChild = null;
            }
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des données')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectChild(Map<String, dynamic> child) {
    setState(() {
      _selectedChild = child;
    });
  }

  // Dans le fichier parent_messages_screen.dart, modifiez la méthode _sendMessage() :

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChild == null) {
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final childId = _selectedChild!['id'];
      final structureId = _selectedChild!['structureId'];

      // Ajouter le message à la collection exchanges
      await _firestore.collection('exchanges').add({
        'childId': childId,
        'senderId': user.uid,
        'content': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'senderType': 'parent',
        'nonLu':
            true, // On garde cette valeur à true pour l'assistante maternelle
        'readByParent':
            true // Ajouter cette nouvelle propriété pour indiquer que le parent a déjà lu ce message
      });

      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message envoyé avec succès')),
      );
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi du message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Messages",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryBlue,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Sélecteur d'enfant (si plusieurs enfants)
                    if (_children.length > 1)
                      Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Sélectionnez un enfant :",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _children.length,
                                itemBuilder: (context, index) {
                                  final child = _children[index];
                                  final isSelected = _selectedChild != null &&
                                      _selectedChild!['id'] == child['id'];
                                  final isBoy = child['gender'] == 'Garçon';

                                  return GestureDetector(
                                    onTap: () => _selectChild(child),
                                    child: Container(
                                      width: 70,
                                      margin: EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        border: isSelected
                                            ? Border.all(
                                                color: primaryBlue, width: 2)
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 25,
                                            backgroundImage:
                                                child['photoUrl'] != null &&
                                                        child['photoUrl']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? NetworkImage(
                                                        child['photoUrl'])
                                                    : null,
                                            backgroundColor: isBoy
                                                ? primaryBlue.withOpacity(0.2)
                                                : primaryRed.withOpacity(0.2),
                                            child: (child['photoUrl'] == null ||
                                                    child['photoUrl']
                                                        .toString()
                                                        .isEmpty)
                                                ? Icon(
                                                    isBoy
                                                        ? Icons.boy
                                                        : Icons.girl,
                                                    color: isBoy
                                                        ? primaryBlue
                                                        : primaryRed)
                                                : null,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            child['firstName'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? primaryBlue
                                                  : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Contenu des messages
                    Expanded(
                      child: _selectedChild != null
                          ? _buildMessagesStream(_selectedChild!['id'],
                              _selectedChild!['structureId'])
                          : Center(child: Text("Sélectionnez un enfant")),
                    ),

                    // Champ de saisie de message
                    Container(
                      padding: EdgeInsets.all(8.0),
                      color: Colors.white,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.attach_file),
                            onPressed: () {
                              // Fonctionnalité à implémenter plus tard
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Fonctionnalité à venir')),
                              );
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: "Écrivez votre message...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send, color: primaryBlue),
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _isLoading || _children.isEmpty
          ? null
          : BottomNavigationBar(
              currentIndex: 1, // Index actif pour la page Messages
              onTap: (index) {
                if (index == 0) {
                  // Retour à l'accueil
                  context.go('/parent/home');
                } else if (index == 2) {
                  // Vers les stocks - réinitialiser le badge
                  StockBadgeUtil.resetBadge();
                  context.go('/parent/stocks');
                }
              },
              backgroundColor: Colors.white,
              selectedItemColor: primaryBlue,
              unselectedItemColor: Colors
                  .black87, // Utiliser la même couleur que dans home_screen
              elevation: 8,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: TextStyle(fontSize: 12),
              items: [
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'assets/images/maison_icon.png',
                    width: 60,
                    height: 60,
                  ),
                  label: "Journal",
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      Image.asset(
                        'assets/images/Icone_Echanges.png',
                        width: 60,
                        height: 60,
                      ),
                      if (_showMessageBadge)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    children: [
                      Image.asset(
                        'assets/images/Icone_Echanges.png',
                        width: 60,
                        height: 60,
                      ),
                      if (_showMessageBadge)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: "Messages",
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      Image.asset(
                        'assets/images/Icone_Stock.png',
                        width: 60,
                        height: 60,
                      ),
                      if (_showStockBadge)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    children: [
                      Image.asset(
                        'assets/images/Icone_Stock.png',
                        width: 60,
                        height: 60,
                        color: primaryBlue,
                      ),
                      if (_showStockBadge)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: "Stocks",
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              "Aucun enfant n'est associé à votre compte pour le moment",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Si vous pensez qu'il s'agit d'une erreur, veuillez contacter votre structure d'accueil.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dans le fichier parent_messages_screen.dart, modifiez la méthode _buildMessagesStream :

  Widget _buildMessagesStream(String childId, String structureId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('exchanges')
          .where('childId', isEqualTo: childId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur de chargement des messages'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data?.docs ?? [];

        // Liste pour stocker les mises à jour de messages
        List<Future<void>> messageUpdates = [];

        // Marquer les messages comme lus UNIQUEMENT pour les messages de l'assistante maternelle
        for (final doc in messages) {
          final message = doc.data() as Map<String, dynamic>;
          if (message['senderType'] == 'staff' && message['nonLu'] == true) {
            // Ajouter la mise à jour à la liste sans attendre
            messageUpdates.add(_firestore
                .collection('exchanges')
                .doc(doc.id)
                .update({'nonLu': false}).then((_) {
              print("✅ Message ${doc.id} marqué comme lu");
            }).catchError((error) {
              print(
                  "❌ Erreur lors de la mise à jour du statut de lecture: $error");
            }));
          }
        }

        // Si des messages ont été marqués comme lus
        if (messageUpdates.isNotEmpty) {
          // Effectuer toutes les mises à jour en parallèle
          Future.wait(messageUpdates).then((_) {
            // Une fois toutes les mises à jour terminées, réinitialiser le badge
            MessageBadgeUtil.resetBadge().then((_) {
              if (mounted) {
                setState(() {
                  _showMessageBadge = false;
                });
              }
            });

            // Mise à jour explicite du compteur de messages non lus
            final user = _auth.currentUser;
            if (user != null) {
              _firestore
                  .collection('users')
                  .doc(user.email?.toLowerCase())
                  .update({'unreadMessages': 0}).then((_) {
                print("✅ Compteur de messages non lus réinitialisé");
              }).catchError((error) {
                print(
                    "❌ Erreur lors de la réinitialisation du compteur: $error");
              });
            }
          });
        }

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  "Aucun message",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Envoyez un premier message à la structure",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          padding: EdgeInsets.all(8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index].data() as Map<String, dynamic>;
            final isMe = message['senderType'] == 'parent';

            return _buildMessageBubble(message, isMe);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final timestamp = message['timestamp'] as Timestamp?;
    final time =
        timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryBlue,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? primaryBlue.withOpacity(0.9) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) SizedBox(width: 8),
        ],
      ),
    );
  }
}
