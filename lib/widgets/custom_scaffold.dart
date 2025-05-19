import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomScaffold extends StatelessWidget {
  final Widget body;
  final String title;

  const CustomScaffold({Key? key, required this.body, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, size: 32), // Réglages à gauche
            label: "Réglages",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled, size: 32), // Home au centre
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white, size: 32),
                onPressed: () {
                  context.go('/child-info'); // Ajout d'enfant
                },
              ),
            ),
            label: "",
          ),
        ],
        onTap: (index) {
          if (index == 0) context.go('/settings'); // Réglages
          if (index == 1) context.go('/home'); // Accueil
        },
      ),
    );
  }
}
