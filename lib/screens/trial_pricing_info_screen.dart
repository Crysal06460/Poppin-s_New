import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TrialPricingInfoScreen extends StatelessWidget {
  const TrialPricingInfoScreen({Key? key}) : super(key: key);

  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: primaryBlue,
        title: Text(
          "Essai gratuit & tarifs",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryBlue,
            fontSize: isTablet ? 22 : 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 40 : 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrialHighlight(isTablet),
              const SizedBox(height: 30),
              _buildBenefits(isTablet),
              const SizedBox(height: 32),
              _buildPricingIntro(isTablet),
              const SizedBox(height: 16),
              _buildPricingCards(isTablet),
              const SizedBox(height: 32),
              _buildGuaranteeCard(isTablet),
              const SizedBox(height: 24),
              _buildCallToAction(context, isTablet),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "Sans engagement • Annulable en 2 clics depuis l'application",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isTablet ? 16 : 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrialHighlight(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 30 : 20,
        vertical: isTablet ? 30 : 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryBlue,
            brightCyan,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.25),
            offset: const Offset(0, 12),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vous êtes sur le point de créer votre compte Poppin's",
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Profitez de 7 jours complets d'essai, sans carte bancaire, sans App Store et sans Google Play. "
            "Testez toutes les fonctionnalités vous et votre équipe avant de vous abonner.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: isTablet ? 18 : 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(bool isTablet) {
    final List<_Benefit> benefits = [
      _Benefit(
        icon: Icons.lock_open_rounded,
        title: "Accès immédiat",
        description:
            "Créez votre compte en 2 minutes, en tant que Assistant(e) Maternel(le) ou en tant que MAM et accéder à toute l'application.",
      ),
      _Benefit(
        icon: Icons.credit_card_off_rounded,
        title: "Aucune carte bancaire",
        description:
            "L'essai démarre automatiquement. Au bout de 7 jours, vous choisissez sereinement si vous souhaitez vous abonner.",
      ),
      _Benefit(
        icon: Icons.autorenew_rounded,
        title: "Sans engagement",
        description:
            "Abonnement résiliable à tout moment depuis l'application. Vous restez maître de vos données.",
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Comment fonctionne l'essai ?",
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        ...benefits.map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    benefit.icon,
                    color: primaryBlue,
                    size: isTablet ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        benefit.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isTablet ? 18 : 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        benefit.description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingIntro(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choisissez l'abonnement adapté à votre activité",
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Des offres simples et transparentes, sans engagement pour les MAM et les Assistant(e)s Maternel(le)s.",
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: isTablet ? 17 : 14.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingCards(bool isTablet) {
    final List<_PlanInfo> plans = [
      _PlanInfo(
        title: "Assistant(e) Maternel(le)",
        description: "Pour une professionnelle seule à domicile ou en MAM",
        price: "3,99 €",
        color: primaryBlue,
        accent: const Color(0xFF60C0FF),
      ),
      _PlanInfo(
        title: "MAM 2 à 3 membres",
        description: "L'abonnement pour une MAM de 2 à 3 professionnelles",
        price: "9,99 €",
        color: const Color(0xFFE45858),
        accent: const Color(0xFFF18E8E),
      ),
      _PlanInfo(
        title: "MAM 4 et + membres",
        description: "L'abonnement pour une MAM de 4 professionnelles et plus",
        price: "14,99 €",
        color: const Color(0xFFF2B705),
        accent: const Color(0xFFFFD567),
      ),
    ];

    final bool useRowLayout = isTablet;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool canFitRow = constraints.maxWidth > 720;
        final bool displayRow = useRowLayout || canFitRow;

        if (displayRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: plans
                .map(
                  (plan) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: isTablet ? 0 : 8,
                      ),
                      child: _PlanCard(plan: plan, isTablet: isTablet),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Column(
          children: plans
              .map(
                (plan) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _PlanCard(plan: plan, isTablet: isTablet),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildGuaranteeCard(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 18,
        vertical: isTablet ? 24 : 20,
      ),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primaryBlue,
            size: isTablet ? 32 : 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "À l'issue des 7 jours d'essai, vous serez redirigé(e) vers la page d'abonnement. "
              "Si vous ne faites rien, l'accès s'arrête automatiquement. Votre essai vous permet "
              "de bien tout essayer avant de vous abonner.",
              style: TextStyle(
                color: Colors.black87,
                fontSize: isTablet ? 17 : 14.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallToAction(BuildContext context, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.push('/register'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 20 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 4,
        ),
        child: Text(
          "Je crée mon compte - Essai 7 jours offert",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 20 : 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Benefit {
  final IconData icon;
  final String title;
  final String description;

  const _Benefit({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _PlanInfo {
  final String title;
  final String description;
  final String price;
  final Color color;
  final Color accent;

  const _PlanInfo({
    required this.title,
    required this.description,
    required this.price,
    required this.color,
    required this.accent,
  });
}

class _PlanCard extends StatelessWidget {
  final _PlanInfo plan;
  final bool isTablet;

  const _PlanCard({
    Key? key,
    required this.plan,
    required this.isTablet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 18 : 16,
        vertical: isTablet ? 28 : 24,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            plan.color,
            plan.accent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: plan.color.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                "assets/images/parapluie.png",
                height: isTablet ? 50 : 42,
                width: isTablet ? 50 : 42,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            plan.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isTablet ? 16 : 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            plan.price,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 40 : 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Toutes les fonctionnalités incluses dans l'abonnement",
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
