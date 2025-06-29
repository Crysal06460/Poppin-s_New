import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// AppBar personnalisé réutilisable pour toutes les pages de fonctionnalités
class CommonAppBar extends StatelessWidget {
  final String title;
  final String structureName;
  final String iconPath;
  final String backRoute;
  final Color primaryColor;

  const CommonAppBar({
    Key? key,
    required this.title,
    required this.structureName,
    required this.iconPath,
    this.backRoute = '/home',
    this.primaryColor = const Color(0xFF3D9DF2),
  }) : super(key: key);

  bool _isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = _isTablet(context);

    return Container(
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
          padding: EdgeInsets.fromLTRB(
            16,
            isTabletDevice ? 24 : 16,
            16,
            isTabletDevice ? 28 : 20,
          ),
          child: Column(
            children: [
              // Première ligne: bouton retour, nom structure et date
              Row(
                children: [
                  // Bouton retour
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.go(backRoute);
                    },
                    child: Container(
                      padding: EdgeInsets.all(isTabletDevice ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: isTabletDevice ? 20 : 18,
                          ),
                          if (isTabletDevice) ...[
                            SizedBox(width: 4),
                            Text(
                              "Home",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 16),

                  // Nom de la structure
                  Expanded(
                    child: Text(
                      structureName,
                      style: TextStyle(
                        fontSize: isTabletDevice ? 28 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Date
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTabletDevice ? 16 : 12,
                      vertical: isTabletDevice ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: isTabletDevice ? 16 : 12,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isTabletDevice ? 22 : 15),

              // Icône et titre de la page
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTabletDevice ? 22 : 16,
                  vertical: isTabletDevice ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: isTabletDevice ? 2.5 : 2,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      iconPath,
                      width: isTabletDevice ? 36 : 30,
                      height: isTabletDevice ? 36 : 30,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.apps,
                        size: isTabletDevice ? 32 : 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isTabletDevice ? 12 : 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isTabletDevice ? 24 : 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    // Indicateur de geste discret
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "👉",
                        style: TextStyle(fontSize: 12),
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
}
