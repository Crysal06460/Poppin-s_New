import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ParentChildPhotoScreen extends StatefulWidget {
  final String childId;
  final String structureId;
  final String childName;

  const ParentChildPhotoScreen({
    Key? key,
    required this.childId,
    required this.structureId,
    required this.childName,
  }) : super(key: key);

  @override
  State<ParentChildPhotoScreen> createState() => _ParentChildPhotoScreenState();
}

class _ParentChildPhotoScreenState extends State<ParentChildPhotoScreen> {
  static const Color primaryColor = Color(0xFF3D9DF2);
  static const Color secondaryColor = Color(0xFFDFE9F2);

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadChildData();
  }

  Future<void> _loadChildData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (!mounted) return;

      setState(() {
        _photoUrl = doc.data()?['photoUrl']?.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger la photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final fileBytes = await File(image.path).readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('children_photos')
          .child(
              '${widget.childId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final newUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .update({'photoUrl': newUrl});

      if (!mounted) return;

      setState(() {
        _photoUrl = newUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo mise à jour avec succès'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        _buildPhotoPreview(),
                        const SizedBox(height: 32),
                        Text(
                          widget.childName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Sélectionnez une nouvelle photo depuis votre galerie.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isUploading ? null : _pickAndUploadPhoto,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera),
                            label: Text(
                              _isUploading
                                  ? 'Chargement...'
                                  : 'Modifier la photo',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildPhotoPreview() {
    final placeholder = CircleAvatar(
      radius: 70,
      backgroundColor: secondaryColor,
      child: Icon(
        Icons.person,
        size: 48,
        color: primaryColor.withValues(alpha: 0.4),
      ),
    );

    if (_photoUrl == null || _photoUrl!.isEmpty) {
      return placeholder;
    }

    return CircleAvatar(
      radius: 70,
      backgroundColor: secondaryColor,
      backgroundImage: NetworkImage(_photoUrl!),
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
            primaryColor,
            primaryColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photo de mon enfant',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.childName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.85),
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

  BottomNavigationBar _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.black87,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle:
          const TextStyle(fontSize: 12, color: Colors.black87),
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/noel/Icone_home_noel.png',
            width: 60,
            height: 60,
          ),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/noel/Icone_message_noel.png',
            width: 60,
            height: 60,
          ),
          activeIcon: Image.asset(
            'assets/images/noel/Icone_message_noel.png',
            width: 60,
            height: 60,
            color: primaryColor,
          ),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/noel/Icone_stock_noel.png',
            width: 60,
            height: 60,
          ),
          activeIcon: Image.asset(
            'assets/images/noel/Icone_stock_noel.png',
            width: 60,
            height: 60,
            color: primaryColor,
          ),
          label: 'Stocks',
        ),
      ],
      onTap: (index) {
        if (index == 0) {
          context.go('/parent/home');
        } else if (index == 1) {
          context.go('/parent/messages');
        } else if (index == 2) {
          context.go('/parent/stocks');
        }
      },
    );
  }
}
