import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/structure_notification_service.dart';
import '../utils/structure_context.dart';

class AdminBroadcastNotificationScreen extends StatefulWidget {
  const AdminBroadcastNotificationScreen({super.key});

  @override
  State<AdminBroadcastNotificationScreen> createState() =>
      _AdminBroadcastNotificationScreenState();
}

const Set<String> _notificationAdminEmails = {
  'cbeylet06@gmail.com',
  'chrisgugu1101@gmail.com',
};

class _AdminBroadcastNotificationScreenState
    extends State<AdminBroadcastNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSubmitting = false;
  bool _isAuthorizing = true;
  bool _isAuthorized = false;
  String? _authorizationError;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthorization() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isAuthorizing = false;
          _authorizationError = 'Utilisateur non authentifié.';
        });
        return;
      }

      final email = currentUser.email?.toLowerCase().trim();
      if (email != null && _notificationAdminEmails.contains(email)) {
        setState(() {
          _isAuthorized = true;
          _isAuthorizing = false;
        });
        return;
      }

      try {
        final structureContext = await StructureResolver().resolve();
        final bool authorizedByStructure =
            structureContext.structureId == 'e5udQot4UtYxsrOoqaHZ2n4VEkk1';
        setState(() {
          _isAuthorized = authorizedByStructure;
          _isAuthorizing = false;
          if (!authorizedByStructure) {
            _authorizationError = 'Accès réservé.';
          }
        });
      } catch (e) {
        setState(() {
          _isAuthorizing = false;
          _authorizationError = 'Accès réservé.';
        });
      }
    } catch (e) {
      setState(() {
        _isAuthorizing = false;
        _authorizationError = 'Accès refusé.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès non autorisé.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final createdBy = currentUser?.email ?? currentUser?.uid ?? 'admin';
      await StructureNotificationService.broadcast(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        createdBy: createdBy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification publiée sur toutes les structures.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la publication : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorizing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Diffusion notification'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Diffusion notification'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _authorizationError ?? 'Accès réservé.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diffusion notification'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cette page vous permet d'envoyer une notification à toutes les structures. "
                  "Elle apparaîtra dans le Dashboard avec le badge rouge.",
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Titre obligatoire';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Message obligatoire';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.send),
                    label: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publier'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
