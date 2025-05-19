import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class ChildSalaryInfoScreen extends StatefulWidget {
  final String childId;
  
  const ChildSalaryInfoScreen({
    Key? key, 
    required this.childId,
  }) : super(key: key);
  
  @override
  _ChildSalaryInfoScreenState createState() => _ChildSalaryInfoScreenState();
}

class _ChildSalaryInfoScreenState extends State<ChildSalaryInfoScreen> {
  final TextEditingController _netSalaryController = TextEditingController();
  final TextEditingController _maintenanceRateController = TextEditingController();
  final TextEditingController _mealRateController = TextEditingController();
  final TextEditingController _kmRateController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> childData = {};
  
  @override
  void initState() {
    super.initState();
    _loadChildData();
  }
  
  @override
  void dispose() {
    _netSalaryController.dispose();
    _maintenanceRateController.dispose();
    _mealRateController.dispose();
    _kmRateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadChildData() async {
    setState(() => _isLoading = true);
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      
      final docSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childId)
          .get();
          
      if (!docSnapshot.exists) {
        throw Exception('Enfant non trouvé');
      }
      
      childData = docSnapshot.data() ?? {};
      
      // Récupérer les informations de salaire si elles existent
      final salaryInfo = childData['salaryInfo'] as Map<String, dynamic>? ?? {};
      
      _netSalaryController.text = (salaryInfo['netSalary'] ?? '').toString();
      _maintenanceRateController.text = (salaryInfo['maintenanceRate'] ?? '').toString();
      _mealRateController.text = (salaryInfo['mealRate'] ?? '').toString();
      _kmRateController.text = (salaryInfo['kmRate'] ?? '').toString();
      
      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Erreur lors du chargement des données: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveSalaryInfo() async {
    // Validation des champs
    if (_netSalaryController.text.isEmpty ||
        _maintenanceRateController.text.isEmpty ||
        _mealRateController.text.isEmpty ||
        _kmRateController.text.isEmpty) {
      _showError('Veuillez remplir tous les champs');
      return;
    }
    
    // Convertir les valeurs en double
    double? netSalary = double.tryParse(_netSalaryController.text.replaceAll(',', '.'));
    double? maintenanceRate = double.tryParse(_maintenanceRateController.text.replaceAll(',', '.'));
    double? mealRate = double.tryParse(_mealRateController.text.replaceAll(',', '.'));
    double? kmRate = double.tryParse(_kmRateController.text.replaceAll(',', '.'));
    
    if (netSalary == null || maintenanceRate == null || mealRate == null || kmRate == null) {
      _showError('Veuillez entrer des valeurs numériques valides');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childId)
          .update({
        'salaryInfo': {
          'netSalary': netSalary,
          'maintenanceRate': maintenanceRate,
          'mealRate': mealRate,
          'kmRate': kmRate,
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Informations de salaire enregistrées')),
      );
      
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      _showError('Erreur lors de l\'enregistrement: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Informations de salaire',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enfant: ${childData['firstName']} ${childData['lastName'] ?? ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Salaire net
                  _buildInputField(
                    label: 'Salaire net mensuel (€)',
                    controller: _netSalaryController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    icon: Icons.euro_symbol,
                  ),
                  SizedBox(height: 16),
                  
                  // Indemnité d'entretien
                  _buildInputField(
                    label: 'Indemnité d\'entretien par jour (€)',
                    controller: _maintenanceRateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    icon: Icons.home_work,
                  ),
                  SizedBox(height: 16),
                  
                  // Indemnité repas
                  _buildInputField(
                    label: 'Indemnité repas (€)',
                    controller: _mealRateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    icon: Icons.restaurant,
                  ),
                  SizedBox(height: 16),
                  
                  // Indemnité kilométrique
                  _buildInputField(
                    label: 'Indemnité kilométrique par km (€)',
                    controller: _kmRateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    icon: Icons.directions_car,
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Bouton de sauvegarde
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSalaryInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Enregistrer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
          ],
          onChanged: (value) {
            if (value.contains(',')) {
              controller.text = value.replaceAll(',', '.');
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      ],
    );
  }
}