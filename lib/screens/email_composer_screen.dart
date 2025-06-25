import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EmailComposerScreen extends StatefulWidget {
  final String recipientEmail;
  final String recipientName;
  final String senderStructureId;
  final String childId;
  final String childName;

  const EmailComposerScreen({
    Key? key,
    required this.recipientEmail,
    required this.recipientName,
    required this.senderStructureId,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  _EmailComposerScreenState createState() => _EmailComposerScreenState();
}

class _EmailComposerScreenState extends State<EmailComposerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _subjectFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();

  bool _isSending = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  // Design System - Même palette que parent_coordonnees_screen
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);
  static const Color surfaceColor = Color(0xFFFAFBFC);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Auto-focus sur le sujet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subjectFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_subjectController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      _showSnackBar("Veuillez remplir le sujet et le message", Colors.orange);
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Appel à une Cloud Function Firebase pour envoyer l'email
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('sendEmail');

      final emailData = {
        'to': widget.recipientEmail,
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
        'senderStructureId': widget.senderStructureId,
        'recipientName': widget.recipientName,
        'childId': widget.childId,
        'childName': widget.childName,
      };

      final result = await callable.call(emailData);

      // Sauvegarder l'email dans Firestore pour l'historique
      await _saveEmailToHistory(emailData);

      _showSnackBar("Email envoyé avec succès !", Colors.green);

      // Attendre un peu pour que l'utilisateur voie le message de succès
      await Future.delayed(Duration(seconds: 1));
      Navigator.pop(context, true); // Retourner true pour indiquer le succès
    } catch (e) {
      _showSnackBar("Erreur lors de l'envoi : ${e.toString()}", primaryRed);
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _saveEmailToHistory(Map<String, dynamic> emailData) async {
    try {
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.senderStructureId)
          .collection('emailHistory')
          .add({
        ...emailData,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'sent',
      });
    } catch (e) {
      print('Erreur sauvegarde historique: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required FocusNode focusNode,
    int maxLines = 1,
    TextInputAction? textInputAction,
    VoidCallback? onEditingComplete,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            textInputAction: textInputAction,
            onEditingComplete: onEditingComplete,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textPrimary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: textSecondary.withOpacity(0.6),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
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
          // Header avec design moderne
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, brightCyan],
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
                    // Bouton retour
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
                    // Titre
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Nouveau message",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "À ${widget.recipientName}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bouton d'envoi
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSending ? null : _sendEmail,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSending) ...[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                ] else
                                  Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                SizedBox(width: 8),
                                Text(
                                  _isSending ? "Envoi..." : "Envoyer",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu du formulaire
          Expanded(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, _slideAnimation.value),
                end: Offset.zero,
              ).animate(_slideAnimation),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Destinataire (en lecture seule)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lightBlue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryBlue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryBlue, brightCyan],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Destinataire",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "${widget.recipientName} (${widget.recipientEmail})",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Champ sujet
                    _buildTextField(
                      controller: _subjectController,
                      label: "Sujet",
                      hint: "Entrez le sujet de votre message...",
                      focusNode: _subjectFocus,
                      textInputAction: TextInputAction.next,
                      onEditingComplete: () => _bodyFocus.requestFocus(),
                    ),

                    // Champ message
                    _buildTextField(
                      controller: _bodyController,
                      label: "Message",
                      hint: "Rédigez votre message ici...",
                      focusNode: _bodyFocus,
                      maxLines: 8,
                      textInputAction: TextInputAction.newline,
                    ),

                    // Info sur l'enfant
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryYellow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: primaryYellow.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: primaryYellow,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Ce message concerne ${widget.childName}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),
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
