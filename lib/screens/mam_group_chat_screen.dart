import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MamGroupChatScreen extends StatefulWidget {
  final String mamId;

  const MamGroupChatScreen({Key? key, required this.mamId}) : super(key: key);

  @override
  State<MamGroupChatScreen> createState() => _MamGroupChatScreenState();
}

class _MamGroupChatScreenState extends State<MamGroupChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();

  late Future<Stream<QuerySnapshot>> _messagesStreamFuture;
  bool _isSending = false;
  bool _isUploadingFile = false;

  static const Color _primaryBlue = Color(0xFF3D9DF2);
  static const Color _bubbleGrey = Color(0xFFF4F6F8);

  @override
  void initState() {
    super.initState();
    _messagesStreamFuture = _createMessagesStream();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<Stream<QuerySnapshot>> _createMessagesStream() async {
    final baseQuery = _firestore
        .collection('exchanges')
        .where('mamId', isEqualTo: widget.mamId);

    try {
      await baseQuery.orderBy('timestamp', descending: true).limit(1).get();
      return baseQuery.orderBy('timestamp', descending: true).snapshots();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        return baseQuery.snapshots();
      }
      rethrow;
    }
  }

  Future<String> _getSenderDisplayName(User user) async {
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.toLowerCase();
    if (email != null && email.isNotEmpty) {
      final userDoc = await _firestore.collection('users').doc(email).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final firstName = data?['firstName']?.toString().trim() ?? '';
        final lastName = data?['lastName']?.toString().trim() ?? '';
        final fullName = '$firstName $lastName'.trim();
        if (fullName.isNotEmpty) {
          return fullName;
        }
        final fallback = data?['fullName']?.toString().trim() ?? '';
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
    }

    return email ?? user.uid;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      final senderName = await _getSenderDisplayName(user);
      final senderFcmToken = await FirebaseMessaging.instance.getToken();

      await _firestore.collection('exchanges').add({
        'mamId': widget.mamId,
        'senderId': user.uid,
        'senderEmail': user.email?.toLowerCase(),
        'senderName': senderName,
        'senderType': 'mam_member',
        'content': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'nonLu': true,
        'senderFcmToken': senderFcmToken,
      });

      _messageController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'envoi du message: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final user = _auth.currentUser;
    if (user == null || _isUploadingFile) return;

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
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Fichier non valide');
      }

      if (file.size > 10 * 1024 * 1024) {
        throw Exception('Le fichier est trop volumineux (maximum 10MB)');
      }

      final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final storagePath =
          'mam_group_messages/${widget.mamId}/$timestamp-${file.name}';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'mamId': widget.mamId,
          'senderId': user.uid,
          'originalName': file.name,
        },
      );

      await storageRef.putData(bytes, metadata);
      final downloadUrl = await storageRef.getDownloadURL();

      final senderName = await _getSenderDisplayName(user);
      final senderFcmToken = await FirebaseMessaging.instance.getToken();

      await _firestore.collection('exchanges').add({
        'mamId': widget.mamId,
        'senderId': user.uid,
        'senderEmail': user.email?.toLowerCase(),
        'senderName': senderName,
        'senderType': 'mam_member',
        'type': 'file',
        'fileName': file.name,
        'fileUrl': downloadUrl,
        'fileType': mimeType,
        'fileSize': file.size,
        'timestamp': FieldValue.serverTimestamp(),
        'nonLu': true,
        'senderFcmToken': senderFcmToken,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier envoyé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Exception:')
                  ? e.toString().split('Exception: ').last
                  : "Erreur lors de l'envoi du fichier",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  Widget _buildMessagesView() {
    return FutureBuilder<Stream<QuerySnapshot>>(
      future: _messagesStreamFuture,
      builder: (context, streamSnapshot) {
        if (streamSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (streamSnapshot.hasError) {
          return const Center(
            child: Text('Erreur de chargement des messages'),
          );
        }
        if (!streamSnapshot.hasData) {
          return const Center(child: Text('Aucun message'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Erreur de chargement des messages'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Commencez la discussion avec votre équipe MAM.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final messages = List<QueryDocumentSnapshot>.from(docs);
            messages.sort((a, b) {
              final aTs =
                  (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final bTs =
                  (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
              final bMillis = bTs?.millisecondsSinceEpoch ?? 0;
              return bMillis.compareTo(aMillis);
            });

            final currentUserId = _auth.currentUser?.uid;

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final data = messages[index].data() as Map<String, dynamic>;
                final isMe = data['senderId'] == currentUserId;
                return _buildMessageBubble(data, isMe);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final type = (message['type'] ?? 'text').toString();
    final timestamp = message['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? DateFormat('dd/MM HH:mm').format(timestamp.toDate())
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _primaryBlue.withOpacity(0.15),
                child: const Icon(Icons.person, color: _primaryBlue),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? _primaryBlue.withOpacity(0.1) : _bubbleGrey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        (message['senderName'] ?? message['senderEmail'] ?? '')
                            .toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  type == 'file'
                      ? _buildFileMessage(message, isMe)
                      : Text(
                          (message['content'] ?? message['text'] ?? '')
                              .toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> message, bool isMe) {
    final fileType = message['fileType']?.toString() ?? '';
    final isImage = fileType.startsWith('image/');
    final fileName = (message['fileName'] ?? 'Fichier').toString();

    Future<void> openFile() async {
      try {
        final fileUrl = message['fileUrl']?.toString();
        if (fileUrl == null || fileUrl.isEmpty) {
          throw 'URL du fichier non disponible';
        }

        if (await canLaunchUrlString(fileUrl)) {
          await launchUrlString(fileUrl);
        } else {
          throw 'Impossible d\'ouvrir le fichier';
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: openFile,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                Icon(
                  isImage ? Icons.image : Icons.insert_drive_file,
                  color: isMe ? _primaryBlue : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      color: isMe ? _primaryBlue : Colors.black87,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.open_in_new, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
        if (isImage && message['fileUrl'] != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              message['fileUrl'],
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 220,
                  height: 160,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Row(
          children: [
            IconButton(
              onPressed: _isUploadingFile ? null : _pickAndSendFile,
              icon: _isUploadingFile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Écrire un message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              child: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie interne MAM (groupe)'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesView()),
          _buildComposer(),
        ],
      ),
    );
  }
}
