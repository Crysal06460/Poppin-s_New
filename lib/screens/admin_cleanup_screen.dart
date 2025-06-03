import 'package:flutter/material.dart';
import '../services/photo_cleanup_service.dart';
import 'package:intl/intl.dart';

class AdminCleanupScreen extends StatefulWidget {
  const AdminCleanupScreen({Key? key}) : super(key: key);

  @override
  _AdminCleanupScreenState createState() => _AdminCleanupScreenState();
}

class _AdminCleanupScreenState extends State<AdminCleanupScreen> {
  bool _isLoading = false;
  Map<String, int> _stats = {};
  DateTime? _lastCleanup;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await PhotoCleanupService.getCleanupStats();
      final lastCleanup = await PhotoCleanupService.getLastCleanupDate();

      setState(() {
        _stats = stats;
        _lastCleanup = lastCleanup;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Erreur lors du chargement: $e");
    }
  }

  Future<void> _forceCleanup() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await PhotoCleanupService.forceCleanup();
      _showSuccessSnackBar("Nettoyage terminé avec succès");
      await _loadData(); // Recharger les données
    } catch (e) {
      _showErrorSnackBar("Erreur lors du nettoyage: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirmer le nettoyage"),
              content: Text(
                  "Êtes-vous sûr de vouloir supprimer toutes les photos de plus de ${PhotoCleanupService.getRetentionDays()} jours ?\n\nCette action est irréversible."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child:
                      Text("Supprimer", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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
      appBar: AppBar(
        title: Text("Gestion des photos"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Statistiques",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildStatRow("Photos totales",
                              "${_stats['totalPhotos'] ?? 0}"),
                          _buildStatRow("Photos anciennes",
                              "${_stats['oldPhotos'] ?? 0}"),
                          _buildStatRow("Rétention",
                              "${_stats['retentionDays'] ?? 0} jours"),
                          if (_lastCleanup != null)
                            _buildStatRow(
                                "Dernier nettoyage",
                                DateFormat('dd/MM/yyyy à HH:mm')
                                    .format(_lastCleanup!))
                          else
                            _buildStatRow(
                                "Dernier nettoyage", "Jamais effectué"),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Actions",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _forceCleanup,
                              icon: Icon(Icons.delete_sweep),
                              label: Text("Forcer le nettoyage"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _loadData,
                              icon: Icon(Icons.refresh),
                              label: Text("Actualiser les données"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                "Informations",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            "• Le nettoyage automatique s'exécute une fois par jour\n"
                            "• Les photos sont conservées pendant ${PhotoCleanupService.getRetentionDays()} jours\n"
                            "• La suppression concerne uniquement les photos\n",
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
