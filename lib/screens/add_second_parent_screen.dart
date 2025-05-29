import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSecondParentScreen extends StatefulWidget {
  final String childId;

  const AddSecondParentScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _AddSecondParentScreenState createState() => _AddSecondParentScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

String structureName = "Chargement...";
bool isLoadingStructure = true;

class _AddSecondParentScreenState extends State<AddSecondParentScreen> {
  int _selectedIndex = 2; // Pour la barre de navigation du bas

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    // AJOUT : Charger les infos de structure
    _loadStructureInfo();
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
      // Déjà sur cette page
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadStructureInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoadingStructure = false);
        return;
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
              "🔄 Add Second Parent: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupération des informations de la structure avec l'ID correct
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data() as Map<String, dynamic>;
        setState(() {
          structureName = data['structureName'] ?? 'Structure inconnue';
          isLoadingStructure = false;
        });
      } else {
        setState(() {
          structureName = 'Structure inconnue';
          isLoadingStructure = false;
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des infos de structure: $e");
      setState(() {
        structureName = 'Erreur de chargement';
        isLoadingStructure = false;
      });
    }
  }

  Widget _buildTabletLayout() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double contentWidth = (maxWidth * 0.6).clamp(400.0, 600.0);

      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: (maxWidth * 0.05).clamp(20.0, 50.0),
            vertical: (maxHeight * 0.02).clamp(10.0, 30.0),
          ),
          child: Container(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Card principale avec explication
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all((maxWidth * 0.04).clamp(24.0, 40.0)),
                  child: Column(
                    children: [
                      // En-tête avec icône
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                                (maxWidth * 0.015).clamp(12.0, 20.0)),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.family_restroom,
                              color: primaryBlue,
                              size: (maxWidth * 0.03).clamp(28.0, 40.0),
                            ),
                          ),
                          SizedBox(width: (maxWidth * 0.02).clamp(16.0, 24.0)),
                          Flexible(
                            child: Text(
                              "Ajout d'un deuxième parent",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.024).clamp(20.0, 28.0),
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: (maxHeight * 0.03).clamp(20.0, 30.0)),

                      // Description
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(
                            (maxWidth * 0.025).clamp(20.0, 30.0)),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          "Souhaitez-vous ajouter un deuxième parent pour cet enfant ou continuer les autres étapes d'inscription ?",
                          style: TextStyle(
                            fontSize: (maxWidth * 0.018).clamp(15.0, 20.0),
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (maxHeight * 0.05).clamp(30.0, 50.0)),

                // Icône illustration centrale
                Container(
                  padding: EdgeInsets.all((maxWidth * 0.035).clamp(30.0, 50.0)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        lightBlue.withOpacity(0.7),
                        lightBlue,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.2),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.family_restroom,
                    size: (maxWidth * 0.08).clamp(80.0, 120.0),
                    color: primaryBlue,
                  ),
                ),

                SizedBox(height: (maxHeight * 0.06).clamp(40.0, 60.0)),

                // Boutons d'action
                Column(
                  children: [
                    // Bouton ajouter parent
                    _buildButtonTablet(
                      text: "Ajouter un deuxième parent",
                      icon: Icons.person_add,
                      onPressed: () {
                        print(
                            "DEBUG - Bouton 'Ajouter parent' - childId: '${widget.childId}'");
                        if (widget.childId.isNotEmpty) {
                          print(
                              "✅ Redirection vers parent-second-info avec childId: ${widget.childId}");
                          context.go('/parent-second-info',
                              extra: widget.childId);
                        } else {
                          _showError("Erreur : ID d'enfant manquant !");
                        }
                      },
                      color: primaryBlue,
                      isPrimary: true,
                      maxWidth: maxWidth,
                      maxHeight: maxHeight,
                    ),

                    SizedBox(height: (maxHeight * 0.02).clamp(16.0, 24.0)),

                    // Bouton continuer
                    _buildButtonTablet(
                      text: "Continuer l'ajout de l'enfant",
                      icon: Icons.arrow_forward,
                      onPressed: () {
                        print(
                            "DEBUG - Bouton 'Continuer' - childId avant navigation: '${widget.childId}'");
                        if (widget.childId.isNotEmpty) {
                          print(
                              "✅ Redirection vers schedule-info avec childId: ${widget.childId}");
                          context.go('/schedule-info', extra: widget.childId);
                        } else {
                          _showError("Erreur : ID d'enfant manquant !");
                        }
                      },
                      color: Colors.grey.shade400,
                      isPrimary: false,
                      maxWidth: maxWidth,
                      maxHeight: maxHeight,
                    ),
                  ],
                ),

                SizedBox(height: (maxHeight * 0.04).clamp(30.0, 50.0)),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildButtonTablet({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required bool isPrimary,
    required double maxWidth,
    required double maxHeight,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: (maxWidth * 0.4).clamp(300.0, 450.0),
      ),
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: isPrimary ? Colors.white : Colors.white,
          size: (maxWidth * 0.022).clamp(20.0, 28.0),
        ),
        label: Text(
          text,
          style: TextStyle(
            fontSize: (maxWidth * 0.02).clamp(16.0, 22.0),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: (maxWidth * 0.03).clamp(25.0, 40.0),
            vertical: (maxHeight * 0.025).clamp(18.0, 25.0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isPrimary ? 4 : 2,
          shadowColor:
              isPrimary ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG - AddSecondParentScreen reçoit childId: '${widget.childId}'");

    // Déterminer si on est sur iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: isTabletDevice
                ? _buildTabletLayout() // Layout spécifique pour iPad
                : SingleChildScrollView(
                    // Layout original pour iPhone
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "🔄 Retour vers parent-address avec childId: ${widget.childId}");
                              context.go('/parent-address',
                                  extra: widget.childId);
                            } else {
                              _showError("Erreur : ID d'enfant manquant !");
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: lightBlue,
                            foregroundColor: primaryBlue,
                            padding: EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Card with explanation
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.family_restroom,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Ajout d'un deuxième parent",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Souhaitez-vous ajouter un deuxième parent pour cet enfant ou continuer les autres étapes d'inscription ?",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 30),

                        // Icon illustration
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.family_restroom,
                              size: 80,
                              color: primaryBlue,
                            ),
                          ),
                        ),

                        SizedBox(height: 40),

                        // Add second parent button
                        _buildButton(
                          text: "Ajouter un deuxième parent",
                          icon: Icons.person_add,
                          onPressed: () {
                            print(
                                "DEBUG - Bouton 'Ajouter parent' - childId: '${widget.childId}'");
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "✅ Redirection vers parent-second-info avec childId: ${widget.childId}");
                              context.go('/parent-second-info',
                                  extra: widget.childId);
                            } else {
                              _showError("Erreur : ID d'enfant manquant !");
                            }
                          },
                          color: primaryBlue,
                          isLoading: false,
                        ),

                        SizedBox(height: 20),

                        // Continue button
                        _buildButton(
                          text: "Continuer l'ajout de l'enfant",
                          icon: Icons.arrow_forward,
                          onPressed: () {
                            print(
                                "DEBUG - Bouton 'Continuer' - childId avant navigation: '${widget.childId}'");
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "✅ Redirection vers schedule-info avec childId: ${widget.childId}");
                              context.go('/schedule-info',
                                  extra: widget.childId);
                            } else {
                              _showError("Erreur : ID d'enfant manquant !");
                            }
                          },
                          color: Colors.grey.shade400,
                          isLoading: false,
                        ),

                        SizedBox(height: 60),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildAppBar() {
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              // Structure name and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName, // CHANGEMENT : utiliser structureName au lieu de "Poppins"
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              // Page title with icon
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Deuxième Parent',
                      style: TextStyle(
                        fontSize: 20,
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

  Widget _buildButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        icon: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(icon, color: Colors.white, size: 22),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }

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
