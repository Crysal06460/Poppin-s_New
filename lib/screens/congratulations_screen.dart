import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CongratulationsScreen extends StatelessWidget {
  final String structureType;
  final bool skipStructureFlow;

  const CongratulationsScreen({
    Key? key,
    required this.structureType,
    this.skipStructureFlow = false,
  }) : super(key: key);

  static const Color _primaryBlue = Color(0xFF3D9DF2);
  static const Color _secondaryBlue = Color(0xFF1E75D8);
  static const Color _lightBackground = Color(0xFFF5F8FF);

  @override
  Widget build(BuildContext context) {
    print(
        "🎉 CongratulationsScreen -> structureType: '$structureType', skipFlow: $skipStructureFlow");

    final String actionLabel =
        skipStructureFlow ? "Accéder à mon tableau de bord" : "Continuer";

    return Scaffold(
      backgroundColor: _lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primaryBlue, _secondaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.celebration_rounded,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Félicitations !",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            skipStructureFlow
                                ? "Votre accès premium est maintenant actif."
                                : "Votre compte a été créé avec succès.",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      elevation: 3,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skipStructureFlow
                                  ? "Bienvenue dans l'abonnement Poppin’s."
                                  : "Merci de continuer la création de votre compte.",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              skipStructureFlow
                                  ? "Vous pouvez dès maintenant accéder à toutes vos fonctionnalités. Vos informations de structure sont déjà enregistrées."
                                  : "Complétez quelques informations pour finaliser votre profil et profiter de Poppin’s.",
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (skipStructureFlow) {
                      context.go('/home');
                    } else {
                      context.go('/structure-confirmation', extra: {
                        'structureType': structureType,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
