import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _primaryRed = Color(0xFFD94350);
const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue = Color(0xFFDFE9F2);
const Color _brightCyan = Color(0xFF05C7F2);
const Color _primaryYellow = Color(0xFFF2B705);

enum _DocStatus { valid, expiringSoon, expired }

class _DocumentType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _DocumentType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_DocumentType> _documentTypes = [
  _DocumentType(
    id: 'secourisme',
    label: 'Diplôme secourisme (PSC1/AFGSU)',
    icon: Icons.health_and_safety_rounded,
    color: _primaryRed,
  ),
  _DocumentType(
    id: 'assurance',
    label: 'Assurance responsabilité civile',
    icon: Icons.shield_rounded,
    color: _primaryBlue,
  ),
  _DocumentType(
    id: 'agrement',
    label: 'Agrément assistante maternelle',
    icon: Icons.verified_rounded,
    color: _brightCyan,
  ),
  _DocumentType(
    id: 'formation',
    label: 'Formation continue',
    icon: Icons.school_rounded,
    color: _primaryYellow,
  ),
  _DocumentType(
    id: 'autre',
    label: 'Autre document',
    icon: Icons.folder_rounded,
    color: Color(0xFF9B59B6),
  ),
];

class DocumentsScreen extends StatefulWidget {
  final String structureId;

  const DocumentsScreen({Key? key, required this.structureId})
      : super(key: key);

  @override
  _DocumentsScreenState createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('documents')
          .orderBy('uploadedAt', descending: true)
          .get();

      setState(() {
        _documents = snap.docs.map((d) {
          return {...d.data(), 'id': d.id};
        }).toList();
      });
    } catch (e) {
      _showSnack('Erreur lors du chargement des documents', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  _DocStatus _getStatus(Map<String, dynamic> doc) {
    final expiresAt = doc['expiresAt'];
    if (expiresAt == null) return _DocStatus.valid;
    final expiry = (expiresAt as Timestamp).toDate();
    final now = DateTime.now();
    final diff = expiry.difference(now).inDays;
    if (diff < 0) return _DocStatus.expired;
    if (diff <= 30) return _DocStatus.expiringSoon;
    return _DocStatus.valid;
  }

  _DocumentType _resolveType(String typeId) {
    return _documentTypes.firstWhere(
      (t) => t.id == typeId,
      orElse: () => _documentTypes.last,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _primaryRed : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openAddDocumentSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddDocumentSheet(
        structureId: widget.structureId,
        onAdded: () {
          _loadDocuments();
          _showSnack('Document ajouté avec succès');
        },
      ),
    );
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce document ?'),
        content: Text(
          'Le document "${doc['name'] ?? ''}" sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: _primaryRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final url = doc['url'] as String?;
      if (url != null && url.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('documents')
          .doc(doc['id'] as String)
          .delete();

      setState(() {
        _documents.removeWhere((d) => d['id'] == doc['id']);
      });
      _showSnack('Document supprimé');
    } catch (e) {
      _showSnack('Erreur lors de la suppression', isError: true);
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack("Impossible d'ouvrir le document", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mes documents',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            )
          : _documents.isEmpty
              ? _buildEmptyState()
              : _buildDocumentList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDocumentSheet,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun document',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ajoutez vos documents professionnels\n(diplôme, agrément, assurance…)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF636E72),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openAddDocumentSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Ajouter un document',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildDocumentCard(_documents[index]);
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final typeId = (doc['type'] as String?) ?? 'autre';
    final docType = _resolveType(typeId);
    final status = _getStatus(doc);
    final uploadedAt = doc['uploadedAt'] != null
        ? (doc['uploadedAt'] as Timestamp).toDate()
        : null;
    final expiresAt = doc['expiresAt'] != null
        ? (doc['expiresAt'] as Timestamp).toDate()
        : null;
    final name = (doc['name'] as String?) ?? docType.label;
    final url = (doc['url'] as String?) ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: url.isNotEmpty ? () => _openDocument(url) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: docType.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    docType.icon,
                    color: docType.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3436),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (uploadedAt != null)
                        Text(
                          'Ajouté le ${DateFormat('dd/MM/yyyy').format(uploadedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF636E72),
                          ),
                        ),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Expire le ${DateFormat('dd/MM/yyyy').format(expiresAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: status == _DocStatus.expired
                                ? _primaryRed
                                : status == _DocStatus.expiringSoon
                                    ? _primaryYellow
                                    : const Color(0xFF636E72),
                            fontWeight: status != _DocStatus.valid
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildStatusChip(status),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (url.isNotEmpty)
                      Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _deleteDocument(doc),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: _primaryRed,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(_DocStatus status) {
    late final Color bg;
    late final Color fg;
    late final String label;
    late final IconData icon;

    switch (status) {
      case _DocStatus.valid:
        bg = const Color(0xFFE8F8F0);
        fg = const Color(0xFF27AE60);
        label = 'Valide';
        icon = Icons.check_circle_rounded;
        break;
      case _DocStatus.expiringSoon:
        bg = _primaryYellow.withOpacity(0.15);
        fg = const Color(0xFFD68910);
        label = 'Expire bientôt';
        icon = Icons.warning_amber_rounded;
        break;
      case _DocStatus.expired:
        bg = _primaryRed.withOpacity(0.1);
        fg = _primaryRed;
        label = 'Expiré';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDocumentSheet extends StatefulWidget {
  final String structureId;
  final VoidCallback onAdded;

  const _AddDocumentSheet({
    required this.structureId,
    required this.onAdded,
  });

  @override
  _AddDocumentSheetState createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  _DocumentType _selectedType = _documentTypes.first;
  final TextEditingController _nameController = TextEditingController();
  DateTime? _expiresAt;
  PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;
  bool _isUploading = false;
  bool _useCustomName = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _documentTypes.first.label;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.first;
      _pickedBytes = _pickedFile!.bytes;
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      locale: const Locale('fr', 'FR'),
      helpText: "Date d'expiration",
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _submit() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner un fichier'),
          backgroundColor: _primaryRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Non authentifié');

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
      final storagePath =
          'structures/${widget.structureId}/documents/$fileName';
      final ref = FirebaseStorage.instance.ref(storagePath);

      final bytes = _pickedBytes ?? _pickedFile!.bytes;
      final UploadTask uploadTask;
      if (bytes != null) {
        uploadTask = ref.putData(bytes);
      } else if (_pickedFile!.path != null) {
        uploadTask = ref.putFile(File(_pickedFile!.path!));
      } else {
        throw Exception('Données du fichier introuvables');
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final name = _useCustomName && _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : _selectedType.label;

      final docData = <String, dynamic>{
        'type': _selectedType.id,
        'name': name,
        'url': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': user.uid,
      };
      if (_expiresAt != null) {
        docData['expiresAt'] = Timestamp.fromDate(_expiresAt!);
      }

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('documents')
          .add(docData);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'upload : $e"),
          backgroundColor: _primaryRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ajouter un document',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Type de document',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF636E72),
                ),
              ),
              const SizedBox(height: 10),
              _buildTypeSelector(),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Text(
                    'Nom personnalisé',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF636E72),
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _useCustomName,
                    onChanged: (v) {
                      setState(() {
                        _useCustomName = v;
                        if (!v) {
                          _nameController.text = _selectedType.label;
                        }
                      });
                    },
                    activeColor: _primaryBlue,
                  ),
                ],
              ),
              if (_useCustomName) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Nom du document',
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              const Text(
                "Date d'expiration (optionnelle)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF636E72),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickExpiry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(14),
                    border: _expiresAt != null
                        ? Border.all(color: _primaryBlue, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: _expiresAt != null
                            ? _primaryBlue
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _expiresAt != null
                            ? DateFormat('dd/MM/yyyy').format(_expiresAt!)
                            : "Aucune date d'expiration",
                        style: TextStyle(
                          color: _expiresAt != null
                              ? const Color(0xFF2D3436)
                              : Colors.grey.shade400,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (_expiresAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _expiresAt = null),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Fichier (PDF ou image)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF636E72),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _isUploading ? null : _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _pickedFile != null
                        ? _primaryBlue.withOpacity(0.06)
                        : const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pickedFile != null
                          ? _primaryBlue
                          : Colors.grey.shade300,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _pickedFile != null
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_rounded,
                        size: 40,
                        color: _pickedFile != null
                            ? _primaryBlue
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFile != null
                            ? _pickedFile!.name
                            : 'Appuyez pour choisir un fichier',
                        style: TextStyle(
                          color: _pickedFile != null
                              ? _primaryBlue
                              : Colors.grey.shade500,
                          fontWeight: _pickedFile != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if (_pickedFile == null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'PDF, JPG, PNG',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryBlue.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _documentTypes.map((type) {
        final isSelected = _selectedType.id == type.id;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedType = type;
              if (!_useCustomName) {
                _nameController.text = type.label;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? type.color.withOpacity(0.12)
                  : const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? type.color : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.icon,
                  size: 18,
                  color: isSelected ? type.color : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? type.color : const Color(0xFF636E72),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
