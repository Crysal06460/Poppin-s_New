import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_composer_screen.dart';
import 'package:url_launcher/url_launcher.dart'; // AJOUT en haut du fichier

class ParentCoordonneesScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String structureId;

  const ParentCoordonneesScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.structureId,
  }) : super(key: key);

  @override
  _ParentCoordonneesScreenState createState() =>
      _ParentCoordonneesScreenState();
}

class _ParentCoordonneesScreenState extends State<ParentCoordonneesScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  Map<String, dynamic> parentInfo = {};
  Map<String, dynamic> parentAddress = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Design System 2025 - Palette officielle de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Couleurs dérivées pour le design system
  static const Color surfaceColor = Color(0xFFFAFBFC);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadParentInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadParentInfo() async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? {};

        setState(() {
          parentInfo = {
            'parent1': data['parent1'] ?? {},
            'parent2': data['parent2'] ?? {},
          };
          parentAddress = {
            'parent1': data['parentAddress'] ?? {},
            'parent2': data['parent2Address'] ?? {},
          };
          isLoading = false;
        });

        _animationController.forward();
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildParentSection(String parentKey, String parentTitle, int index) {
    final parent = parentInfo[parentKey] ?? {};
    final parentAddr = parentAddress[parentKey] ?? {};

    if (parent.isEmpty && parentAddr.isEmpty) {
      return SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec gradient subtil
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryBlue.withOpacity(0.08),
                          brightCyan.withOpacity(0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryBlue, brightCyan],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parentTitle,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (parent['firstName'] != null ||
                                  parent['lastName'] != null)
                                Text(
                                  "${parent['firstName'] ?? ''} ${parent['lastName'] ?? ''}"
                                      .trim(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu des informations
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Email avec fonctionnalité d'envoi
                        if (parent['email'] != null &&
                            parent['email'].toString().isNotEmpty)
                          _buildModernInfoRow(
                            Icons.email_rounded,
                            "Email",
                            parent['email'].toString(),
                            Colors.indigo,
                            isClickable: true,
                            onTap: () => _handleEmailTap(
                                parent['email'].toString(), parentKey),
                          ),

                        // Téléphone
                        if (parent['phone'] != null &&
                            parent['phone'].toString().isNotEmpty)
                          _buildModernInfoRow(
                            Icons.phone_rounded,
                            "Téléphone",
                            parent['phone'].toString(),
                            Colors.green,
                          ),

                        // Adresse
                        if (parentAddr.isNotEmpty)
                          _buildModernInfoRow(
                            Icons.location_on_rounded,
                            "Adresse",
                            _formatAddress(parentAddr),
                            Colors.orange,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Méthode corrigée pour les infos avec support email cliquable
  Widget _buildModernInfoRow(
    IconData icon,
    String label,
    String value,
    Color iconColor, {
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône avec design moderne
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),

                SizedBox(width: 16),

                // Contenu texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicateur pour email cliquable
                if (isClickable) ...[
                  SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryBlue, brightCyan],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Méthode corrigée pour gérer le clic sur l'email
  Future<void> _handleEmailTap(String email, String parentKey) async {
    // Créer l'URL mailto simple - JUSTE l'adresse email
    final mailtoUrl = 'mailto:$email';

    try {
      // Ouvrir l'app de messagerie native
      if (await canLaunchUrl(Uri.parse(mailtoUrl))) {
        await launchUrl(Uri.parse(mailtoUrl));
      } else {
        // Fallback si pas d'app mail configurée
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Aucune application de messagerie configurée'),
                  ),
                ],
              ),
              backgroundColor: primaryRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Erreur: ${e.toString()}')),
              ],
            ),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  String _formatAddress(Map<String, dynamic> parentAddr) {
    List<String> addressParts = [];

    if (parentAddr['address'] != null &&
        parentAddr['address'].toString().isNotEmpty) {
      addressParts.add(parentAddr['address'].toString());
    }

    if (parentAddr['postalCode'] != null &&
        parentAddr['postalCode'].toString().isNotEmpty) {
      if (parentAddr['city'] != null &&
          parentAddr['city'].toString().isNotEmpty) {
        addressParts.add("${parentAddr['postalCode']} ${parentAddr['city']}");
      } else {
        addressParts.add(parentAddr['postalCode'].toString());
      }
    } else if (parentAddr['city'] != null &&
        parentAddr['city'].toString().isNotEmpty) {
      addressParts.add(parentAddr['city'].toString());
    }

    return addressParts.join('\n');
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue.withOpacity(0.1),
                  brightCyan.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.contact_page_rounded,
              size: 48,
              color: textSecondary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            "Aucune coordonnée disponible",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Les informations des parents n'ont pas encore été renseignées",
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
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
          // Header moderne avec glassmorphism
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryBlue,
                  brightCyan,
                ],
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
                    // Bouton retour avec effet glassmorphism
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
                    // Titre avec typographie moderne
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Coordonnées parents",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            widget.childName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal
          Expanded(
            child: isLoading
                ? Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: primaryBlue,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                : (parentInfo['parent1']?.isEmpty != false &&
                        parentInfo['parent2']?.isEmpty != false &&
                        parentAddress['parent1']?.isEmpty != false &&
                        parentAddress['parent2']?.isEmpty != false)
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Parent 1
                              _buildParentSection('parent1', 'Parent 1', 0),

                              // Parent 2
                              _buildParentSection('parent2', 'Parent 2', 1),

                              // Espace pour le scroll final
                              SizedBox(height: 20),
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
