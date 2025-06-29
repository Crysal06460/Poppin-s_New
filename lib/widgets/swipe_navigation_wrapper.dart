import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Widget réutilisable pour ajouter la navigation par gestes à n'importe quelle page
class SwipeNavigationWrapper extends StatefulWidget {
  final Widget child;
  final String backRoute;
  final bool showSwipeIndicator;

  const SwipeNavigationWrapper({
    Key? key,
    required this.child,
    this.backRoute = '/home',
    this.showSwipeIndicator = true,
  }) : super(key: key);

  @override
  _SwipeNavigationWrapperState createState() => _SwipeNavigationWrapperState();
}

class _SwipeNavigationWrapperState extends State<SwipeNavigationWrapper>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragDistance = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _dragDistance = 0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragDistance += details.delta.dx;
      // Limiter la distance pour éviter un déplacement trop important
      _dragDistance = _dragDistance.clamp(-50, 200);
    });

    // Animer l'indicateur quand on commence à swiper vers la droite
    if (_dragDistance > 50) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    _isDragging = false;
    _animationController.reverse();

    const double minSwipeDistance = 100.0;
    const double minSwipeVelocity = 300.0;

    final double velocity = details.velocity.pixelsPerSecond.dx;
    final bool hasMinVelocity = velocity > minSwipeVelocity;
    final bool hasMinDistance = _dragDistance > minSwipeDistance;

    setState(() {
      _dragDistance = 0;
    });

    // Si le swipe est suffisant, naviguer
    if (hasMinVelocity || hasMinDistance) {
      HapticFeedback.lightImpact();
      context.go(widget.backRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Stack(
        children: [
          // Contenu principal avec transformation
          Transform.translate(
            offset:
                Offset(_dragDistance * 0.3, 0), // Effet de déplacement subtil
            child: widget.child,
          ),

          // Indicateur visuel du swipe
          if (widget.showSwipeIndicator)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).padding.top + 100,
                  left: 20 + (_animation.value * 10),
                  child: Opacity(
                    opacity: _animation.value,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF3D9DF2).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Retour Home",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Extension pour faciliter l'utilisation
extension SwipeNavigation on Widget {
  /// Ajoute la navigation par swipe vers Home
  Widget withSwipeToHome() {
    return SwipeNavigationWrapper(
      backRoute: '/home',
      child: this,
    );
  }

  /// Ajoute la navigation par swipe vers une route personnalisée
  Widget withSwipeBack(String backRoute) {
    return SwipeNavigationWrapper(
      backRoute: backRoute,
      child: this,
    );
  }

  /// Ajoute la navigation par swipe sans indicateur visuel
  Widget withSwipeBackSilent(String backRoute) {
    return SwipeNavigationWrapper(
      backRoute: backRoute,
      showSwipeIndicator: false,
      child: this,
    );
  }
}
