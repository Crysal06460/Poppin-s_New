import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeHeader extends StatelessWidget {
  final String structureName;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Map<String, dynamic>> childrenToday;
  final List<Map<String, dynamic>> upcomingBirthdays;

  const HomeHeader({
    Key? key,
    required this.structureName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.childrenToday,
    required this.upcomingBirthdays,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Column(
      children: [
        // En-tête avec fond de couleur
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.85),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // Nom de la structure et date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          structureName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                ],
              ),
            ),
          ),
        ),
        
        // Section des enfants présents avec effet d'élévation
        Container(
          margin: const EdgeInsets.fromLTRB(16, -20, 16, 0),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre avec icône
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_alt_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Enfants présents aujourd'hui",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Grille d'avatars des enfants présents
                childrenToday.isEmpty
                    ? Center(
                        child: Text(
                          "Aucun enfant prévu aujourd'hui",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: childrenToday.map((child) => _buildChildAvatar(child)).toList(),
                      ),
                
                // Section des anniversaires
                if (upcomingBirthdays.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cake_rounded,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Anniversaires à venir",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: upcomingBirthdays.length,
                      itemBuilder: (context, index) {
                        return _buildBirthdayCard(upcomingBirthdays[index]);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildAvatar(Map<String, dynamic> child) {
    final isBoy = child['gender'] == 'Garçon';
    final displayName = child['firstName'] ?? 'Enfant';
    final photoUrl = child['photoUrl'];
    
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isBoy 
                ? [primaryColor.withOpacity(0.7), primaryColor]
                : [Colors.pink.withOpacity(0.7), Colors.pink],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isBoy ? primaryColor : Colors.pink).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: photoUrl != null && photoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(displayName),
                  ),
                )
              : _buildFallbackAvatar(displayName),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayCard(Map<String, dynamic> birthday) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade100,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo ou avatar
          ClipOval(
            child: Container(
              width: 50,
              height: 50,
              color: Colors.white,
              child: birthday['photoUrl'] != null && birthday['photoUrl'].toString().isNotEmpty
                ? Image.network(
                    birthday['photoUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person,
                      color: Colors.orange.shade300,
                      size: 30,
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: Colors.orange.shade300,
                    size: 30,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  birthday['firstName'] ?? "Enfant",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.cake,
                      color: Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Dans ${birthday['daysUntilBirthday']} jour${birthday['daysUntilBirthday'] > 1 ? 's' : ''}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}