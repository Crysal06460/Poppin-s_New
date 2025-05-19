import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Color primaryColor;

  const CustomBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined, size: 28),
            activeIcon: Icon(Icons.dashboard, size: 28),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 28),
            activeIcon: Icon(Icons.home_filled, size: 28),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: _buildAddButton(context, primaryColor),
            label: "",
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, Color color) {
    return FloatingActionButton(
      onPressed: () => context.go('/child-info'),
      backgroundColor: color,
      elevation: 4,
      mini: false,
      child: const Icon(Icons.add, color: Colors.white, size: 32),
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/home');
        break;
      case 2:
        // Le FloatingActionButton gère déjà la navigation
        break;
    }
  }
}