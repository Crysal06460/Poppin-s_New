import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({Key? key}) : super(key: key);

  @override
  _ParentSettingsScreenState createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  String _parentName = "";
  String _parentEmail = "";
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }
      
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _parentName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}";
          _parentEmail = userData['email'] ?? '';
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _logout() async {
    await _auth.signOut();
    context.go('/login');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paramètres"),
        backgroundColor: const Color(0xFF8B8FE5),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Informations personnelles",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow("Nom", _parentName),
                        const Divider(),
                        _buildInfoRow("Email", _parentEmail),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text("Changer de mot de passe"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Implémenter plus tard
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text("Notifications"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Implémenter plus tard
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Se déconnecter"),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : BottomNavigationBar(
              currentIndex: 2,
              onTap: (index) {
                if (index == 0) {
                  context.go('/parent/home');
                } else if (index == 1) {
                  context.go('/parent/messages');
                }
              },
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF8B8FE5),
              unselectedItemColor: Colors.grey,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Accueil",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message),
                  label: "Messages",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: "Paramètres",
                ),
              ],
            ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}