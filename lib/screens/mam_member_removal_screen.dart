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

  Widget _buildTabletContent() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double sideMargin = maxWidth * 0.03;
      final double columnGap = maxWidth * 0.025;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          sideMargin,
          maxHeight * 0.02,
          sideMargin,
          maxHeight * 0.02,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau latéral gauche (Informations et statut)
            Expanded(
              flex: 4,
              child: Container(
                margin: EdgeInsets.only(right: columnGap),
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
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre avec icône
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryRed,
                            size: maxWidth * 0.07,
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Expanded(
                            child: Text(
                              "Informations",
                              style: TextStyle(
                                fontSize: maxWidth * 0.022,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Carte d'information principale
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(maxWidth * 0.025),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              lightBlue.withOpacity(0.3),
                              lightBlue.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: lightBlue,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryBlue,
                              size: maxWidth * 0.04,
                            ),
                            SizedBox(height: maxHeight * 0.02),
                            Text(
                              "Suppression de membre",
                              style: TextStyle(
                                fontSize: maxWidth * 0.018,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: maxHeight * 0.015),
                            Text(
                              "Cette page vous permet de supprimer un membre de votre MAM. Cette action est définitive et supprimera toutes les données associées à ce membre.",
                              style: TextStyle(
                                fontSize: maxWidth * 0.014,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Statistiques des membres
                      _buildTabletInfoCard(
                        icon: Icons.people,
                        title: "Membres trouvés",
                        value: "${members.length}",
                        maxWidth: maxWidth,
                        color: primaryBlue,
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Avertissement
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(maxWidth * 0.02),
                        decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: primaryRed,
                              size: maxWidth * 0.03,
                            ),
                            SizedBox(height: maxHeight * 0.01),
                            Text(
                              "Attention",
                              style: TextStyle(
                                fontSize: maxWidth * 0.016,
                                fontWeight: FontWeight.bold,
                                color: primaryRed,
                              ),
                            ),
                            SizedBox(height: maxHeight * 0.01),
                            Text(
                              "La suppression d'un membre est définitive et irréversible",
                              style: TextStyle(
                                fontSize: maxWidth * 0.013,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Panneau de droite (Liste des membres)
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
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre de la section
                      Text(
                        "Liste des membres",
                        style: TextStyle(
                          fontSize: maxWidth * 0.022,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Message d'erreur
                      if (errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(maxWidth * 0.02),
                          margin: EdgeInsets.only(bottom: maxHeight * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error,
                                  color: Colors.red, size: maxWidth * 0.02),
                              SizedBox(width: maxWidth * 0.015),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: maxWidth * 0.014,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Liste des membres ou état vide
                      Expanded(
                        child: members.isEmpty
                            ? _buildTabletEmptyState(maxWidth, maxHeight)
                            : _buildTabletMembersList(maxWidth, maxHeight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

// Méthode pour créer une carte d'information pour iPad
  Widget _buildTabletInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required double maxWidth,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(maxWidth * 0.015),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: maxWidth * 0.025,
            ),
          ),
          SizedBox(width: maxWidth * 0.02),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: maxWidth * 0.014,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: maxWidth * 0.005),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: maxWidth * 0.018,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Méthode pour l'état vide sur iPad
  Widget _buildTabletEmptyState(double maxWidth, double maxHeight) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: maxWidth * 0.08,
            color: Colors.grey.withOpacity(0.7),
          ),
          SizedBox(height: maxHeight * 0.03),
          Text(
            "Aucun membre à afficher",
            style: TextStyle(
              fontSize: maxWidth * 0.020,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: maxHeight * 0.01),
          Text(
            "Il n'y a actuellement aucun membre dans votre MAM",
            style: TextStyle(
              fontSize: maxWidth * 0.014,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

// Méthode pour la liste des membres sur iPad
  Widget _buildTabletMembersList(double maxWidth, double maxHeight) {
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Container(
          margin: EdgeInsets.only(bottom: maxHeight * 0.02),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(maxWidth * 0.02),
            child: Row(
              children: [
                // Avatar du membre
                Container(
                  width: maxWidth * 0.06,
                  height: maxWidth * 0.06,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue.withOpacity(0.7), primaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${member['firstName'].isNotEmpty ? member['firstName'][0] : '?'}${member['lastName'].isNotEmpty ? member['lastName'][0] : '?'}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: maxWidth * 0.018,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: maxWidth * 0.02),
                // Informations du membre
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${member['firstName']} ${member['lastName']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: maxWidth * 0.016,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: maxWidth * 0.005),
                      Text(
                        "Email: ${member['email']}",
                        style: TextStyle(
                          fontSize: maxWidth * 0.013,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member['isSelf'] == true)
                        Container(
                          margin: EdgeInsets.only(top: maxWidth * 0.005),
                          padding: EdgeInsets.symmetric(
                            horizontal: maxWidth * 0.01,
                            vertical: maxWidth * 0.003,
                          ),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Vous",
                            style: TextStyle(
                              fontSize: maxWidth * 0.011,
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Bouton de suppression
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showRemoveConfirmation(member),
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: maxWidth * 0.025,
                        vertical: maxWidth * 0.01,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryRed, primaryRed.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_remove,
                            color: Colors.white,
                            size: maxWidth * 0.015,
                          ),
                          SizedBox(width: maxWidth * 0.008),
                          Text(
                            "Supprimer",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: maxWidth * 0.013,
                            ),
                          ),
                        ],
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

// Méthode pour le contenu iPhone (améliorée)
  Widget _buildPhoneContent() {
    return SafeArea(
      child: Column(
        children: [
          // En-tête explicatif amélioré
          Container(
            padding: EdgeInsets.all(20),
            margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  lightBlue.withOpacity(0.3),
                  lightBlue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lightBlue),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: primaryBlue,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  "Suppression de membre",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
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

          // Statistiques
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: primaryBlue, size: 24),
                SizedBox(width: 12),
                Text(
                  "Membres trouvés: ${members.length}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Message d'erreur
          if (errorMessage.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Liste vide ou liste des membres
          Expanded(
            child: members.isEmpty
                ? _buildPhoneEmptyState()
                : _buildPhoneMembersList(),
          ),
        ],
      ),
    );
  }

// Méthode pour l'état vide sur iPhone
  Widget _buildPhoneEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.7),
          ),
          SizedBox(height: 24),
          Text(
            "Aucun membre à afficher",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Il n'y a actuellement aucun membre dans votre MAM que vous pouvez supprimer",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

// Méthode pour la liste des membres sur iPhone
  Widget _buildPhoneMembersList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar du membre
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryBlue.withOpacity(0.7), primaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${member['firstName'].isNotEmpty ? member['firstName'][0] : '?'}${member['lastName'].isNotEmpty ? member['lastName'][0] : '?'}",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Informations du membre
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${member['firstName']} ${member['lastName']}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Email: ${member['email']}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (member['isSelf'] == true) ...[
                            SizedBox(height: 6),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Vous",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Bouton de suppression
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showRemoveConfirmation(member),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryRed, primaryRed.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_remove,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Supprimer ce membre",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
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
        );
      },
    );
  }

// Améliorer la méthode _showRemoveConfirmation existante
  void _showRemoveConfirmation(Map<String, dynamic> member) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: primaryRed,
                size: isTablet ? 32 : 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Confirmation de suppression",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: isTablet ? 500 : double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Vous êtes sur le point de supprimer définitivement le membre:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.1),
                        Colors.grey.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryBlue.withOpacity(0.7),
                        radius: isTablet ? 24 : 20,
                        child: Text(
                          "${member['firstName'].isNotEmpty ? member['firstName'][0] : '?'}${member['lastName'].isNotEmpty ? member['lastName'][0] : '?'}",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 18 : 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "${member['firstName']} ${member['lastName']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 18 : 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        member['email'],
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                          fontSize: isTablet ? 14 : 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
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
                        size: isTablet ? 32 : 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "ATTENTION : Cette action est définitive et ne pourra pas être annulée. Toutes les données associées à ce membre seront effacées définitivement.",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: isTablet ? 14 : 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      "ANNULER",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _removeMember(member);
                      },
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryRed, primaryRed.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: primaryRed.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          "CONFIRMER",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 16 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

  // Remplacer la méthode build() existante par celle-ci
  @override
  Widget build(BuildContext context) {
    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Responsive
          Container(
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
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(screenSize.width * 0.06),
                bottomRight: Radius.circular(screenSize.width * 0.06),
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
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * 0.02,
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * (isTablet ? 0.02 : 0.025),
                ),
                child: Row(
                  children: [
                    // Bouton retour avec meilleur contraste
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(
                            screenSize.width * (isTablet ? 0.015 : 0.02)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: screenSize.width * (isTablet ? 0.025 : 0.06),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: screenSize.width * (isTablet ? 0.02 : 0.04)),
                    // Titre avec meilleur style
                    Expanded(
                      child: Text(
                        "Retrait d'un membre",
                        style: TextStyle(
                          fontSize:
                              screenSize.width * (isTablet ? 0.028 : 0.055),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal avec adaptation pour iPad
          isLoading
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  ),
                )
              : Expanded(
                  child:
                      isTablet ? _buildTabletContent() : _buildPhoneContent(),
                ),
        ],
      ),
    );
  }
}
