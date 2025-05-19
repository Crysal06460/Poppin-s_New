import 'package:flutter/material.dart';

class TestPhotoScreen extends StatelessWidget {
  final String imageUrl =
      "https://firebasestorage.googleapis.com/v0/b/poppin-s-app.firebasestorage.app/o/children_photos%2F9IEXwSeZutfEcnGkgsei.jpg?alt=media&token=b36c6f08-f350-40b9-9504-58175cb100fa"; // Remplace par l'URL de ton image

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Test Photo"),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, error, __) {
            print('Erreur de chargement de l\'image: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
