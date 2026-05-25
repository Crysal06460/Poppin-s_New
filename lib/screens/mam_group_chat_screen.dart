import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/voice_message_service.dart';
import '../widgets/voice_message_widget.dart';

class MamGroupChatScreen extends StatefulWidget {
  final String structureId;
  const MamGroupChatScreen({Key? key, required this.structureId})
      : super(key: key);

  @override
  State<MamGroupChatScreen> createState() => _MamGroupChatScreenState();
}

class _MamGroupChatScreenState extends State<MamGroupChatScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  final Map<String, Future<String>> _resolvedNames = {};
  bool _sending = false;
  bool _uploading = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isSendingVoice = false;
  Duration _recordingDuration = Duration.zero;
  double _dragOffset = 0.0;
  Timer? _recordingTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color _primaryBlue = Color(0xFF3D9DF2);
  static const Color _primaryRed = Color(0xFFD94350);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;
    final started = await VoiceMessageService.startRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone requise'),
            backgroundColor: _primaryRed,
          ),
        );
      }
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _dragOffset = 0.0;
    });
    _pulseController.repeat(reverse: true);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _recordingDuration =
              Duration(seconds: _recordingDuration.inSeconds + 1);
        });
      }
    });
  }

  Future<void> _stopAndSendVoice() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _pulseController.stop();
    setState(() {
      _isRecording = false;
      _isSendingVoice = true;
    });
    HapticFeedback.lightImpact();

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final localPath = await VoiceMessageService.stopRecording();
      if (localPath == null) {
        setState(() => _isSendingVoice = false);
        return;
      }

      if (_recordingDuration.inSeconds < 1) {
        setState(() => _isSendingVoice = false);
        return;
      }

      final messageRef = _firestore
          .collection('structures')
          .doc(widget.structureId)
          .collection('mam_chat')
          .doc('default')
          .collection('messages')
          .doc();

      final uploaded = await VoiceMessageService.uploadAudio(
        localPath: localPath,
        conversationId: 'mam_${widget.structureId}',
        messageId: messageRef.id,
      );

      final senderName = await _resolveSenderName(user);
      final fcmToken = await FirebaseMessaging.instance.getToken();

      await messageRef.set({
        'type': 'audio',
        'audioUrl': uploaded.url,
        'duration': uploaded.duration,
        'senderId': user.uid,
        'senderEmail': (user.email ?? '').toLowerCase(),
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'structureId': widget.structureId,
        'senderFcmToken': fcmToken ?? '',
        'notificationSent': false,
      });
    } catch (e) {
      debugPrint('Erreur envoi vocal MAM: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur lors de l'envoi du message vocal"),
            backgroundColor: _primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingVoice = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _pulseController.stop();
    await VoiceMessageService.cancelRecording();
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _dragOffset = 0.0;
    });
  }

  Widget? _buildSenderLabel({
    required bool isMe,
    required String senderName,
    required String senderEmail,
  }) {
    final name = senderName.trim();
    final email = senderEmail.trim();
    final lowerEmail = email.toLowerCase();
    final textAlign = isMe ? TextAlign.right : TextAlign.left;
    final textStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: isMe ? Colors.blueGrey.shade700 : Colors.grey.shade800,
    );

    final hasReadableName =
        name.isNotEmpty && (lowerEmail.isEmpty || name.toLowerCase() != lowerEmail);

    if (hasReadableName) {
      return Text(name, style: textStyle, textAlign: textAlign);
    }

    if (email.isEmpty) {
      if (name.isNotEmpty) {
        return Text(name, style: textStyle, textAlign: textAlign);
      }
      if (isMe) {
        final user = _auth.currentUser;
        if (user != null) {
          final fallback = <String>[
            (user.displayName ?? '').trim(),
            (user.email ?? '').trim(),
            user.uid,
          ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
          if (fallback.isNotEmpty) {
            return Text(fallback, style: textStyle, textAlign: textAlign);
          }
        }
      }
      return null;
    }

    return FutureBuilder<String>(
      future: _resolveDisplayNameForEmail(email),
      builder: (context, snapshot) {
        final resolved = (snapshot.data ?? '').trim();
        final label = resolved.isNotEmpty
            ? resolved
            : (name.isNotEmpty ? name : email);
        if (label.isEmpty) return const SizedBox.shrink();
        return Text(label, style: textStyle, textAlign: textAlign);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie interne MAM'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('structures')
                  .doc(widget.structureId)
                  .collection('mam_chat')
                  .doc('default')
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = (data['senderEmail'] ?? '')
                            .toString()
                            .toLowerCase() ==
                        (_auth.currentUser?.email ?? '').toLowerCase();
                    final ts = data['timestamp'];
                    final time = ts is Timestamp
                        ? DateFormat('dd/MM HH:mm').format(ts.toDate())
                        : '';
                    final type = (data['type'] ?? 'text').toString();
                    final senderName =
                        (data['senderName'] ?? '').toString().trim();
                    final senderEmail =
                        (data['senderEmail'] ?? '').toString().trim();
                    final senderLabelWidget = _buildSenderLabel(
                      isMe: isMe,
                      senderName: senderName,
                      senderEmail: senderEmail,
                    );
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: type == 'audio'
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (senderLabelWidget != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: senderLabelWidget,
                                    ),
                                  VoiceMessageBubble(
                                    audioUrl:
                                        (data['audioUrl'] ?? '').toString(),
                                    durationSeconds:
                                        (data['duration'] as num?)?.toInt() ??
                                            0,
                                    isMe: isMe,
                                    time: time,
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 280),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF3D9DF2).withOpacity(0.12)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (senderLabelWidget != null)
                                    senderLabelWidget,
                                  if (type == 'file')
                                    _FileBubble(
                                      fileName:
                                          (data['fileName'] ?? '').toString(),
                                      url: (data['fileUrl'] ?? '').toString(),
                                    )
                                  else
                                    Text(
                                      (data['text'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    time,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isRecording)
            VoiceRecordingOverlay(
              duration: _recordingDuration,
              dragOffset: _dragOffset,
              pulseAnimation: _pulseAnimation,
            )
          else
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    if (_isSendingVoice)
                      LinearProgressIndicator(
                        backgroundColor: _primaryBlue.withOpacity(0.15),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_primaryBlue),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              _uploading || _isSendingVoice
                                  ? null
                                  : _pickAndSendFile,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.attach_file),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendText(),
                            decoration: const InputDecoration(
                              hintText: 'Écrire un message...',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14)),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bouton micro avec appui long
                        GestureDetector(
                          onLongPressStart: (_) => _startVoiceRecording(),
                          onLongPressEnd: (_) => _stopAndSendVoice(),
                          onLongPressMoveUpdate: (details) {
                            setState(() {
                              _dragOffset =
                                  details.localOffsetFromOrigin.dx;
                            });
                            if (_dragOffset < -80) {
                              _cancelVoiceRecording();
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryBlue.withOpacity(0.12),
                            ),
                            child: Icon(
                              Icons.mic_rounded,
                              color: _primaryBlue,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _sending || _isSendingVoice
                              ? null
                              : _sendText,
                          child: _sending
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<String> _resolveSenderName(User user) async {
    final rawEmail = (user.email ?? '').trim();
    final lowerEmail = rawEmail.toLowerCase();
    final emailCandidates = <String>{rawEmail, lowerEmail}
        .where((value) => value.isNotEmpty)
        .toList();

    String _formatName(Map<String, dynamic>? data) {
      if (data == null) return '';
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      return [firstName, lastName]
          .where((part) => part.isNotEmpty)
          .join(' ')
          .trim();
    }

    try {
      if (rawEmail.isNotEmpty) {
        final userDoc =
            await _firestore.collection('users').doc(rawEmail).get();
        final resolved = _formatName(userDoc.data());
        if (resolved.isNotEmpty) return resolved;
      }

      if (lowerEmail.isNotEmpty && lowerEmail != rawEmail) {
        final userDoc =
            await _firestore.collection('users').doc(lowerEmail).get();
        final resolved = _formatName(userDoc.data());
        if (resolved.isNotEmpty) return resolved;
      }

      final membersRef = _firestore
          .collection('structures')
          .doc(widget.structureId)
          .collection('members');

      if (emailCandidates.isNotEmpty) {
        final byEmail = await membersRef
            .where('email', whereIn: emailCandidates)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final resolved = _formatName(byEmail.docs.first.data());
          if (resolved.isNotEmpty) return resolved;
        }
      }

      final byId = await membersRef.doc(user.uid).get();
      final resolved = _formatName(byId.data());
      if (resolved.isNotEmpty) return resolved;
    } catch (_) {}

    if (rawEmail.isNotEmpty) return rawEmail;
    return (user.displayName ?? user.uid).trim();
  }

  Future<String> _resolveDisplayNameForEmail(String email) {
    final rawEmail = email.trim();
    if (rawEmail.isEmpty) return Future.value('');
    final cached = _resolvedNames[rawEmail];
    if (cached != null) return cached;

    final future = () async {
      final lowerEmail = rawEmail.toLowerCase();
      final emailCandidates = <String>{rawEmail, lowerEmail}
          .where((value) => value.isNotEmpty)
          .toList();

      String _formatName(Map<String, dynamic>? data) {
        if (data == null) return '';
        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        return [firstName, lastName]
            .where((part) => part.isNotEmpty)
            .join(' ')
            .trim();
      }

      try {
        final usersCollection = _firestore.collection('users');
        final membersRef = _firestore
            .collection('structures')
            .doc(widget.structureId)
            .collection('members');

        final userDocRaw = await usersCollection.doc(rawEmail).get();
        final resolvedRaw = _formatName(userDocRaw.data());
        if (resolvedRaw.isNotEmpty) return resolvedRaw;

        if (lowerEmail.isNotEmpty && lowerEmail != rawEmail) {
          final userDocLower = await usersCollection.doc(lowerEmail).get();
          final resolvedLower = _formatName(userDocLower.data());
          if (resolvedLower.isNotEmpty) return resolvedLower;
        }

        if (emailCandidates.isNotEmpty) {
          final byEmail = await membersRef
              .where('email', whereIn: emailCandidates)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) {
            final resolved = _formatName(byEmail.docs.first.data());
            if (resolved.isNotEmpty) return resolved;
          }
        }
      } catch (_) {}

      return rawEmail;
    }();

    _resolvedNames[rawEmail] = future;
    final lowerEmail = rawEmail.toLowerCase();
    if (lowerEmail != rawEmail) {
      _resolvedNames[lowerEmail] = future;
    }
    return future;
  }

  Future<void> _sendText() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final senderName = await _resolveSenderName(user);
      final fcmToken = await FirebaseMessaging.instance.getToken();
      await _firestore
          .collection('structures')
          .doc(widget.structureId)
          .collection('mam_chat')
          .doc('default')
          .collection('messages')
          .add({
        'type': 'text',
        'text': text,
        'senderId': user.uid,
        'senderEmail': (user.email ?? '').toLowerCase(),
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'structureId': widget.structureId,
        'senderFcmToken': fcmToken ?? '',
        'notificationSent': false,
      });
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      setState(() => _uploading = true);
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes as Uint8List?;
      if (bytes == null) throw Exception('Fichier non valide');
      if (file.size > 15 * 1024 * 1024) {
        throw Exception('Fichier trop volumineux (max 15 Mo)');
      }

      final messageRef = _firestore
          .collection('structures')
          .doc(widget.structureId)
          .collection('mam_chat')
          .doc('default')
          .collection('messages')
          .doc();

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('mam_chats/${widget.structureId}/${messageRef.id}/${file.name}');
      await storageRef.putData(bytes, SettableMetadata(contentType: file.extension));
      final url = await storageRef.getDownloadURL();

      final fcmToken = await FirebaseMessaging.instance.getToken();
      final senderName = await _resolveSenderName(user);
      await messageRef.set({
        'type': 'file',
        'fileName': file.name,
        'fileUrl': url,
        'senderId': user.uid,
        'senderEmail': (user.email ?? '').toLowerCase(),
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'structureId': widget.structureId,
        'senderFcmToken': fcmToken ?? '',
        'notificationSent': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi fichier: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

class _FileBubble extends StatelessWidget {
  final String fileName;
  final String url;
  const _FileBubble({required this.fileName, required this.url});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fileName,
            style: const TextStyle(
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          onPressed: () async {
            // Simple: confier au système via URL
            // Le projet dispose déjà d\'ouverture d\'URL ailleurs, on reste minimal ici
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ouverture du fichier...')),
            );
          },
        )
      ],
    );
  }
}
