import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/photo_cleanup_service.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';
import '../utils/planning_helper.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({Key? key}) : super(key: key);

  @override
  _PhotosScreenState createState() => _PhotosScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

DateTime _selectedDate = DateTime.now();
bool _showingPastPhotos = false;
List<Map<String, dynamic>> _pastPhotos = [];
bool _loadingPastPhotos = false;

class _PhotosScreenState extends State<PhotosScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  int _selectedIndex = 1;
  bool _isUploadingFile = false;
  double _uploadProgress = 0.0;
  List<Uint8List> _webImages = [];
  List<XFile> _pickedPhotos = [];
  XFile? _pickedVideo;
  String _mediaTime = '';
  String _draftMediaTime = '';
  bool _isVideoSelected = false;
  String? _videoDurationText;
  Future<Uint8List?>? _videoThumbFuture;
  VideoPlayerController? _previewController;
  bool _preserveAddMediaDialogState = false;
  // Limites pour les vidéos
  static const int _maxVideoSeconds = 15; // Durée maximale d'une vidéo capturée
  static const int _maxVideoBytes =
      200 * 1024 * 1024; // 200 Mo pour la taille max

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  Color primaryColor =
      primaryBlue; // Utiliser directement la variable déjà définie
  Color secondaryColor = lightBlue;

  @override
  void initState() {
    super.initState();

    // Initialisation de l'animation pour le message d'avertissement

    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
      _performPhotoCleanup();
    });
  }

  Future<void> _performPhotoCleanup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("🧹 Nettoyage des médias ignoré: aucun utilisateur connecté");
        return;
      }

      String? structureId;
      final email = user.email?.toLowerCase() ?? '';

      if (email.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          final storedStructureId = data?['structureId']?.toString().trim();

          if (storedStructureId != null && storedStructureId.isNotEmpty) {
            structureId = storedStructureId;
          }
        }
      }

      structureId ??= user.uid;

      if (structureId.isEmpty) {
        print(
            "🧹 Nettoyage des médias ignoré: structure introuvable pour l'utilisateur courant");
        return;
      }

      await PhotoCleanupService.checkAndCleanupPhotos(
          structureIds: [structureId]);
    } catch (e) {
      print("Erreur lors du nettoyage automatique des photos: $e");
      // Ne pas montrer d'erreur à l'utilisateur car c'est un processus en arrière-plan
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Future<void> _selectMediaTime(
      StateSetter setState, Function(String) onTimeSelected) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    TimeOfDay initialTime;
    if (_mediaTime.isNotEmpty) {
      final parts = _mediaTime.split(':');
      initialTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      initialTime = TimeOfDay.now();
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: primaryColor,
              dayPeriodTextColor: primaryColor,
              dialHandColor: primaryColor,
              dialBackgroundColor: lightBlue.withOpacity(0.2),
              // Fix pour le rectangle bleu
              hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? primaryColor.withOpacity(0.15)
                      : Colors.transparent),
              // Forme pour les conteneurs heure/minute
              hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        onTimeSelected(timeString);
      });
    }
  }

  bool _normalizePermissionValue(dynamic rawValue, {bool defaultValue = true}) {
    if (rawValue is bool) {
      return rawValue;
    }

    if (rawValue is num) {
      return rawValue != 0;
    }

    if (rawValue is String) {
      final normalized = rawValue.trim().toLowerCase();
      if (normalized.isEmpty) {
        return defaultValue;
      }

      const trueValues = {
        'true',
        '1',
        'oui',
        'yes',
        'autorise',
        'autorisé',
      };

      const falseValues = {
        'false',
        '0',
        'non',
        'no',
        'pas autorise',
        'pas autorisé',
        'interdit',
      };

      if (trueValues.contains(normalized)) {
        return true;
      }

      if (falseValues.contains(normalized)) {
        return false;
      }
    }

    return defaultValue;
  }

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final structureContext = await StructureResolver().resolve();
      final String structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final String structureType = structureContext.normalizedStructureType;
      final bool allowAllChildren = structureContext.showAllChildren;

      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      setState(() {
        structureName = structureContext.structureName;
      });

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Appliquer le filtrage selon le type de structure (MAM ou AssistanteMaternelle)
      List<Map<String, dynamic>> filteredChildren = [];
      Set<String> delegatedTodayChildIds = {};
      String? myMemberId;

      if (structureType == 'mam') {
        if (allowAllChildren) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
              "👨‍👧‍👦 Photos: Membre MAM - affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Photos: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
        }
        // ➕ Ajouter enfants délégués aujourd'hui
        try {
          final memSnap = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('members')
              .where('email', isEqualTo: currentUserEmail)
              .limit(1)
              .get();
          if (memSnap.docs.isNotEmpty) {
            myMemberId = memSnap.docs.first.id;
            final now = DateTime.now();
            final start = DateTime(now.year, now.month, now.day);
            final end = start.add(const Duration(days: 1));
            final delSnap = await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .collection('delegations')
                .where('status', isEqualTo: 'accepted')
                .where('amDelegateId', isEqualTo: myMemberId)
                .where('date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThan: Timestamp.fromDate(end))
                .get();
            delegatedTodayChildIds = delSnap.docs
                .map((d) => (d.data()['childId'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet();
            if (delegatedTodayChildIds.isNotEmpty) {
              final already =
                  filteredChildren.map((c) => c['id'] as String).toSet();
              final toAddIds = delegatedTodayChildIds.difference(already);
              if (toAddIds.isNotEmpty) {
                filteredChildren.addAll(allChildren
                    .where((c) => toAddIds.contains(c['id'] as String)));
                print('➕ Photos: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Photos: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Photos: Assistante Maternelle - affichage de tous les enfants");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      enfants = [];
      for (var child in filteredChildren) {
        final isScheduledToday =
            PlanningHelper.isScheduledForDate(child, today);
        final isDelegatedToday = delegatedTodayChildIds.contains(child['id']);
        if (isScheduledToday || isDelegatedToday) {
          String? photoUrl = child['photoUrl'];
          // Récupérer l'autorisation photos en supportant plusieurs formats (booléen, texte, numérique)
          final bool photosAllowed = _normalizePermissionValue(
            child['authorizations']?['photos'],
            defaultValue: true,
          );
          enfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'photosAllowed': photosAllowed,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
          });
        }
      }
      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage(String childId, StateSetter setStateDialog) async {
    final ImagePicker picker = ImagePicker();
    try {
      List<XFile> selectedImages = [];

      try {
        final multiImages = await picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (multiImages != null) {
          selectedImages = multiImages;
        }
      } catch (e) {
        // Certains environnements ne supportent pas pickMultiImage
        print('pickMultiImage indisponible, fallback vers pickImage: $e');
      }

      if (selectedImages.isEmpty) {
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (image != null) {
          selectedImages = [image];
        }
      }

      if (selectedImages.isNotEmpty) {
        final List<Uint8List> newWebImages = [];
        if (kIsWeb) {
          for (final image in selectedImages) {
            final bytes = await image.readAsBytes();
            newWebImages.add(bytes);
            print("Image web chargée: ${bytes.length} bytes");
          }
        }

        setStateDialog(() {
          _pickedPhotos.addAll(selectedImages);
          _isVideoSelected = false;
          _pickedVideo = null;
          _videoThumbFuture = null;
          _videoDurationText = null;
          if (kIsWeb) {
            _webImages.addAll(newWebImages);
          }
        });
      }
    } catch (e) {
      print("Erreur lors de la sélection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sélection: $e")));
    }
  }

  Future<void> _pickCameraImage(String childId,
      [StateSetter? setStateDialog]) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        Uint8List? webBytes;
        if (kIsWeb) {
          webBytes = await image.readAsBytes();
          print("Image web chargée: ${webBytes.length} bytes");
        }

        if (!mounted) return;
        setState(() {
          _pickedPhotos.add(image);
          _isVideoSelected = false;
          _pickedVideo = null;
          _videoThumbFuture = null;
          _videoDurationText = null;
          if (kIsWeb && webBytes != null) {
            _webImages.add(webBytes);
          }
        });
        if (setStateDialog != null) {
          setStateDialog(() {});
        }
      }
    } catch (e) {
      print("Erreur lors de la prise de photo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la prise de photo: $e")));
    }
  }

  Future<void> _pickVideo(String childId, StateSetter setStateDialog) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'La sélection vidéo n\'est pas prise en charge sur le web.')),
      );
      return;
    }
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        // Vérifier la taille du fichier
        final file = File(video.path);
        final bytes = await file.length();
        if (bytes > _maxVideoBytes) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Vidéo trop lourde (> ${(_maxVideoBytes / (1024 * 1024)).round()} Mo). Merci de choisir une vidéo plus courte.')));
          return;
        }
        setStateDialog(() {
          _pickedVideo = video;
          _isVideoSelected = true;
          _pickedPhotos.clear();
          _webImages.clear();
          _videoThumbFuture = VideoThumbnail.thumbnailData(
            video: video.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 640,
            quality: 75,
          );
        });
        // Calculer la durée (mm:ss) de façon asynchrone et légère
        try {
          final tmp = VideoPlayerController.file(file);
          await tmp.initialize();
          final dur = tmp.value.duration;
          await tmp.dispose();
          setStateDialog(() {
            _videoDurationText = _formatDuration(dur);
          });
        } catch (_) {}
      }
    } catch (e) {
      print("Erreur lors de la sélection vidéo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sélection vidéo: $e")));
    }
  }

  Future<void> _pickCameraVideo(String childId,
      [StateSetter? setStateDialog]) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('La caméra vidéo n\'est pas prise en charge sur le web.')),
      );
      return;
    }
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? video = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: Duration(seconds: _maxVideoSeconds));
      if (video != null) {
        // Vérifier la taille du fichier par sécurité
        final file = File(video.path);
        final bytes = await file.length();
        if (bytes > _maxVideoBytes) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Vidéo trop lourde (> ${(_maxVideoBytes / (1024 * 1024)).round()} Mo). Réessayez en filmant plus court.')));
          return;
        }
        if (!mounted) return;
        setState(() {
          _pickedVideo = video;
          _isVideoSelected = true;
          _pickedPhotos.clear();
          _webImages.clear();
          _videoThumbFuture = VideoThumbnail.thumbnailData(
            video: video.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 640,
            quality: 75,
          );
        });
        if (setStateDialog != null) {
          setStateDialog(() {});
        }
        try {
          final tmp = VideoPlayerController.file(file);
          await tmp.initialize();
          final dur = tmp.value.duration;
          await tmp.dispose();
          if (!mounted) return;
          setState(() {
            _videoDurationText = _formatDuration(dur);
          });
          if (setStateDialog != null) {
            setStateDialog(() {});
          }
        } catch (_) {}
      }
    } catch (e) {
      print("Erreur lors de la prise de vidéo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la prise de vidéo: $e")));
    }
  }

  Future<void> _uploadAndSaveImage(String childId) async {
    if (_pickedPhotos.isEmpty) return;

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0.0;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final int total = _pickedPhotos.length;

      for (int index = 0; index < total; index++) {
        final XFile photo = _pickedPhotos[index];
        final Reference ref = FirebaseStorage.instance
            .ref()
            .child('medias')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}_$index.jpg');

        try {
          print("Début upload image ${index + 1}/$total...");

          if (kIsWeb) {
            Uint8List data;
            if (index < _webImages.length) {
              data = _webImages[index];
            } else {
              data = await photo.readAsBytes();
            }
            await ref
                .putData(
                  data,
                  SettableMetadata(contentType: 'image/jpeg'),
                )
                .timeout(Duration(minutes: 2));
          } else {
            final file = File(photo.path);
            final bytes = await file.readAsBytes();
            await ref
                .putData(
                  bytes,
                  SettableMetadata(contentType: 'image/jpeg'),
                )
                .timeout(Duration(minutes: 2));
          }

          final String downloadUrl = await ref.getDownloadURL();
          await _addMediaToFirebase(childId, downloadUrl, type: 'Photo');

          if (mounted) {
            setState(() {
              _uploadProgress = (index + 1) / total;
            });
          }
        } catch (e) {
          print("Erreur détaillée: $e");

          if (e is FirebaseException) {
            print("Code d'erreur Firebase: ${e.code}");
            print("Message Firebase: ${e.message}");
          }

          rethrow;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photos envoyées ($total)'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      print("Erreur globale: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _previewController?.dispose();
      _previewController = null;
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
          _uploadProgress = 0.0;
          _pickedPhotos.clear();
          _webImages.clear();
          _pickedVideo = null;
          _isVideoSelected = false;
          _videoThumbFuture = null;
          _videoDurationText = null;
        });
      } else {
        _pickedPhotos.clear();
        _webImages.clear();
        _pickedVideo = null;
        _isVideoSelected = false;
        _videoThumbFuture = null;
        _videoDurationText = null;
      }
    }
  }

  Future<void> _uploadAndSaveVideo(String childId) async {
    if (_pickedVideo == null) return;

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0.0;
    });

    // Afficher un dialogue de progression pendant l'upload
    StateSetter? dialogSetState;
    bool dialogOpen = false;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setStateDialog) {
              dialogSetState = setStateDialog;
              return WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  title: Text('Envoi de la vidéo'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: (_uploadProgress > 0 && _uploadProgress <= 1)
                            ? _uploadProgress
                            : null,
                      ),
                      SizedBox(height: 12),
                      Text('${(_uploadProgress * 100).toStringAsFixed(0)} %',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        "Merci de patienter, l'envoi peut prendre du temps en 4G",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      dialogOpen = true;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = FirebaseStorage.instance
          .ref()
          .child('medias')
          .child(user.uid)
          .child(fileName);

      String? downloadUrl;

      try {
        print("Début upload vidéo...");

        // Mobile: vérifier la taille et uploader via le fichier directement
        final file = File(_pickedVideo!.path);
        final fileSize = await file.length();
        if (fileSize > _maxVideoBytes) {
          throw Exception(
              'Fichier vidéo trop volumineux (> ${(_maxVideoBytes / (1024 * 1024)).round()} Mo)');
        }
        final uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'video/mp4'),
        );

        final sub = uploadTask.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            final prog = snapshot.bytesTransferred / snapshot.totalBytes;
            if (mounted) {
              setState(() {
                _uploadProgress = prog.clamp(0.0, 1.0);
              });
              // Rafraîchir aussi le contenu du dialogue
              if (dialogSetState != null) {
                dialogSetState!(() {});
              }
            }
            // Fermer automatiquement le dialogue à 100%
            if (snapshot.state == TaskState.success ||
                (snapshot.bytesTransferred >= snapshot.totalBytes &&
                    snapshot.totalBytes > 0)) {
              if (dialogOpen && mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                dialogOpen = false;
              }
            }
          }
        });

        await uploadTask.timeout(Duration(minutes: 20));
        await sub.cancel();

        print("Vidéo uploadée avec succès");
        downloadUrl = await ref.getDownloadURL();

        if (downloadUrl != null) {
          await _addMediaToFirebase(childId, downloadUrl, type: 'Video');
        }
      } catch (e) {
        print("Erreur upload vidéo: $e");
        rethrow;
      }
    } catch (e) {
      print("Erreur globale vidéo: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        // Fermer le dialogue si affiché
        if (dialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogOpen = false;
        }
        setState(() {
          _isUploadingFile = false;
          _uploadProgress = 0.0;
          _pickedVideo = null;
          _isVideoSelected = false;
          _videoThumbFuture = null;
          _videoDurationText = null;
          _pickedPhotos.clear();
          _webImages.clear();
        });
        _previewController?.dispose();
        _previewController = null;
      } else {
        _pickedVideo = null;
        _isVideoSelected = false;
        _videoThumbFuture = null;
        _videoDurationText = null;
        _pickedPhotos.clear();
        _webImages.clear();
        _previewController?.dispose();
        _previewController = null;
      }
    }
  }

  void _showAddMediaPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String? errorMessage;
    String localMediaTime =
        _draftMediaTime.isNotEmpty ? _draftMediaTime : _mediaTime;
    bool showPhotoWarning = enfant['photosAllowed'] == false;

    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              // Largeur adaptée pour iPad
              insetPadding: isTabletDevice
                  ? EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.25)
                  : EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête avec dégradé
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isTabletDevice ? 20 : 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTabletDevice ? 12 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _isVideoSelected
                                    ? Icons.videocam
                                    : Icons.photo_camera,
                                color: Colors.white,
                                size: isTabletDevice ? 30 : 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isVideoSelected
                                        ? "Ajouter une vidéo - ${enfant['prenom']}"
                                        : "Ajouter une photo - ${enfant['prenom']}",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 22 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (isTabletDevice) SizedBox(height: 4),
                                  if (isTabletDevice)
                                    Text(
                                      "Le ${DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.now())}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenu du formulaire avec padding
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avertissement si autorisation refusée
                            if (showPhotoWarning)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.orange.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange.shade800,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Attention",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Lors de l'inscription de ${enfant['prenom']}, l'autorisation pour les photos n'a pas été donnée.",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Aperçu des médias sélectionnés
                            if (_isVideoSelected && _pickedVideo != null) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Aperçu de la vidéo",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      height: 220,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: InkWell(
                                        onTap: () async {
                                          final file = File(_pickedVideo!.path);
                                          _previewController =
                                              VideoPlayerController.file(file);
                                          await _previewController!
                                              .initialize();
                                          _previewController!.setLooping(true);
                                          if (!mounted) return;
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              contentPadding: EdgeInsets.zero,
                                              content: AspectRatio(
                                                aspectRatio: _previewController!
                                                    .value.aspectRatio,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    VideoPlayer(
                                                        _previewController!),
                                                    Positioned(
                                                      bottom: 12,
                                                      child:
                                                          FloatingActionButton
                                                              .small(
                                                        onPressed: () {
                                                          if (_previewController!
                                                              .value
                                                              .isPlaying) {
                                                            _previewController!
                                                                .pause();
                                                          } else {
                                                            _previewController!
                                                                .play();
                                                          }
                                                        },
                                                        child: Icon(
                                                            _previewController!
                                                                    .value
                                                                    .isPlaying
                                                                ? Icons.pause
                                                                : Icons
                                                                    .play_arrow),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ).then((_) async {
                                            await _previewController?.pause();
                                            await _previewController?.dispose();
                                            _previewController = null;
                                          });
                                        },
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            FutureBuilder<Uint8List?>(
                                              future: _videoThumbFuture,
                                              builder: (ctx, snap) {
                                                if (snap.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return Center(
                                                      child:
                                                          CircularProgressIndicator());
                                                }
                                                final bytes = snap.data;
                                                if (bytes == null) {
                                                  return Icon(Icons.videocam,
                                                      size: 64,
                                                      color: Colors.grey[700]);
                                                }
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.memory(
                                                    bytes,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  ),
                                                );
                                              },
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: EdgeInsets.all(8),
                                              child: Icon(Icons.play_arrow,
                                                  size: 36,
                                                  color: Colors.white),
                                            ),
                                            Positioned(
                                              bottom: 8,
                                              left: 12,
                                              right: 12,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  if (_videoDurationText !=
                                                      null)
                                                    _buildChip(
                                                        _videoDurationText!),
                                                  FutureBuilder<int>(
                                                    future:
                                                        File(_pickedVideo!.path)
                                                            .length(),
                                                    builder: (ctx, snap) {
                                                      final sz =
                                                          (snap.data ?? 0);
                                                      final mb = (sz /
                                                              (1024 * 1024))
                                                          .toStringAsFixed(1);
                                                      return _buildChip(
                                                          'Vidéo • $mb Mo');
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              top: 12,
                                              right: 12,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _pickedVideo = null;
                                                    _isVideoSelected = false;
                                                    _videoThumbFuture = null;
                                                    _videoDurationText = null;
                                                  });
                                                  _previewController?.dispose();
                                                  _previewController = null;
                                                },
                                                child: CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: Colors.black
                                                      .withOpacity(0.6),
                                                  child: Icon(Icons.close,
                                                      color: Colors.white,
                                                      size: 18),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (!_isVideoSelected &&
                                _pickedPhotos.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Photos sélectionnées (${_pickedPhotos.length})",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: List.generate(
                                          _pickedPhotos.length, (index) {
                                        final double previewSize =
                                            isTabletDevice ? 140 : 110;
                                        final XFile photo =
                                            _pickedPhotos[index];
                                        Widget preview;
                                        if (kIsWeb) {
                                          Uint8List? bytes;
                                          if (index < _webImages.length) {
                                            bytes = _webImages[index];
                                          }
                                          preview = bytes != null
                                              ? Image.memory(bytes,
                                                  fit: BoxFit.cover)
                                              : Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            primaryColor),
                                                  ),
                                                );
                                        } else {
                                          preview = Image.file(
                                            File(photo.path),
                                            fit: BoxFit.cover,
                                          );
                                        }

                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                width: previewSize,
                                                height: previewSize,
                                                color: Colors.black12,
                                                child: preview,
                                              ),
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (kIsWeb &&
                                                        _webImages.length >
                                                            index) {
                                                      _webImages
                                                          .removeAt(index);
                                                    }
                                                    _pickedPhotos
                                                        .removeAt(index);
                                                    if (_pickedPhotos.isEmpty) {
                                                      _isVideoSelected = false;
                                                      _pickedVideo = null;
                                                      _videoThumbFuture = null;
                                                      _videoDurationText = null;
                                                    }
                                                  });
                                                },
                                                child: CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: Colors.black
                                                      .withOpacity(0.6),
                                                  child: Icon(Icons.close,
                                                      size: 16,
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Heure du média
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure du média",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  InkWell(
                                    onTap: () =>
                                        _selectMediaTime(setState, (time) {
                                      localMediaTime = time;
                                      _draftMediaTime = time;
                                      errorMessage = null;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: localMediaTime.isEmpty
                                              ? Colors.transparent
                                              : primaryColor.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            localMediaTime.isEmpty
                                                ? 'Choisir l\'heure'
                                                : localMediaTime,
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 18 : 16,
                                              color: localMediaTime.isEmpty
                                                  ? Colors.grey.shade600
                                                  : primaryColor,
                                              fontWeight: localMediaTime.isEmpty
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.access_time_rounded,
                                            color:
                                                primaryColor.withOpacity(0.7),
                                            size: isTabletDevice ? 24 : 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Options de choix (Photo/Vidéo depuis Appareil photo ou Galerie)
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Source du média",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            if (localMediaTime.isEmpty) {
                                              setState(() {
                                                errorMessage =
                                                    'Veuillez sélectionner une heure';
                                              });
                                              return;
                                            }

                                            _draftMediaTime = localMediaTime;
                                            _preserveAddMediaDialogState = true;
                                            Navigator.of(context).pop();

                                            await Future.delayed(const Duration(
                                                milliseconds: 120));

                                            try {
                                              await _pickCameraImage(
                                                  enfant['id']);
                                            } finally {
                                              if (!mounted) return;
                                              _showAddMediaPopup(enfant['id']);
                                            }
                                          },
                                          icon: Icon(Icons.camera_alt),
                                          label: Text('Photo (caméra)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              vertical:
                                                  isTabletDevice ? 16 : 12,
                                              horizontal: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (localMediaTime.isEmpty) {
                                              setState(() {
                                                errorMessage =
                                                    'Veuillez sélectionner une heure';
                                              });
                                              return;
                                            }
                                            _pickImage(enfant['id'], setState);
                                          },
                                          icon: Icon(Icons.photo_library),
                                          label: Text('Photo (galerie)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                primaryColor.withOpacity(0.8),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              vertical:
                                                  isTabletDevice ? 16 : 12,
                                              horizontal: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_pickedPhotos.isEmpty) ...[
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              if (localMediaTime.isEmpty) {
                                                setState(() {
                                                  errorMessage =
                                                      'Veuillez sélectionner une heure';
                                                });
                                                return;
                                              }

                                              _draftMediaTime = localMediaTime;
                                              _preserveAddMediaDialogState =
                                                  true;
                                              Navigator.of(context).pop();

                                              await Future.delayed(
                                                  const Duration(
                                                      milliseconds: 120));

                                              try {
                                                await _pickCameraVideo(
                                                    enfant['id']);
                                              } finally {
                                                if (!mounted) return;
                                                _showAddMediaPopup(
                                                    enfant['id']);
                                              }
                                            },
                                            icon: Icon(Icons.videocam),
                                            label: Text('Vidéo (caméra)'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical:
                                                    isTabletDevice ? 16 : 12,
                                                horizontal: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              if (localMediaTime.isEmpty) {
                                                setState(() {
                                                  errorMessage =
                                                      'Veuillez sélectionner une heure';
                                                });
                                                return;
                                              }
                                              _pickVideo(
                                                  enfant['id'], setState);
                                            },
                                            icon: Icon(Icons.video_library),
                                            label: Text('Vidéo (galerie)'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepPurpleAccent,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical:
                                                    isTabletDevice ? 16 : 12,
                                                horizontal: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 16, color: Colors.grey[500]),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Vidéos limitées à ${_maxVideoSeconds}s (≈ ${(_maxVideoBytes / (1024 * 1024)).round()} Mo max) pour un partage rapide.',
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 13 : 12,
                                              color: Colors.grey.shade600,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_pickedPhotos.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                        'Retirez les photos sélectionnées pour accéder aux options vidéo.',
                                        style: TextStyle(
                                          fontSize: isTabletDevice ? 13 : 12,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Message d'erreur si présent
                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: isTabletDevice ? 15 : 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                            // Boutons d'action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Bouton Annuler
                                OutlinedButton(
                                  onPressed: () {
                                    this.setState(() {
                                      _pickedPhotos.clear();
                                      _webImages.clear();
                                      _pickedVideo = null;
                                      _isVideoSelected = false;
                                      _videoThumbFuture = null;
                                      _videoDurationText = null;
                                    });
                                    _previewController?.dispose();
                                    _previewController = null;
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isTabletDevice ? 24 : 16,
                                        vertical: isTabletDevice ? 16 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    "ANNULER",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),

                                // Bouton Confirmer - visible seulement quand un média est sélectionné
                                if (_pickedVideo != null ||
                                    _pickedPhotos.isNotEmpty)
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (localMediaTime.isEmpty) {
                                        setState(() {
                                          errorMessage =
                                              'Veuillez sélectionner une heure';
                                        });
                                        return;
                                      }

                                      _mediaTime = localMediaTime;
                                      Navigator.of(context).pop();

                                      try {
                                        print(
                                            "Début de l'upload après confirmation");
                                        // Faire l'upload seulement après confirmation
                                        if (_pickedVideo != null &&
                                            _isVideoSelected) {
                                          await _uploadAndSaveVideo(childId);
                                        } else {
                                          await _uploadAndSaveImage(childId);
                                        }
                                        print("Upload terminé avec succès");
                                      } catch (e) {
                                        print(
                                            "Erreur capturée lors de l'upload: $e");
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      elevation: 2,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: isTabletDevice ? 32 : 24,
                                          vertical: isTabletDevice ? 16 : 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      _isVideoSelected
                                          ? "ENVOYER LA VIDÉO"
                                          : (_pickedPhotos.length > 1
                                              ? "ENVOYER ${_pickedPhotos.length} PHOTOS"
                                              : "ENVOYER LA PHOTO"),
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (!mounted) return;
      setState(() {
        if (_preserveAddMediaDialogState) {
          _preserveAddMediaDialogState = false;
        } else {
          _draftMediaTime = '';
        }
      });
    });
  }

  Future<bool> _isChildArrivedToday(String structureId, String childId) async {
    try {
      final String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final doc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('horaires')
          .doc(dateKey)
          .get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey(childId)) return false;
      final ch = data[childId] as Map<String, dynamic>?;
      if (ch == null) return false;
      if (ch['actionType'] == 'absent') return false;
      if (ch['segments'] is List) {
        for (final seg in (ch['segments'] as List)) {
          final arr = seg['arrivee'];
          if (arr != null && arr.toString().isNotEmpty) return true;
        }
      }
      final arr = ch['arrivee'];
      if (arr != null && arr.toString().isNotEmpty) return true;
      return false;
    } catch (e) {
      print('Erreur vérification arrivée (photos): $e');
      return false;
    }
  }

  Future<void> _guardAddMedia(String structureId, String childId) async {
    final arrived = await _isChildArrivedToday(structureId, childId);
    if (!arrived) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrivée requise'),
          content: Text(
              "Attention : vous n'avez pas indiqué l'heure d'arrivée.\n\nVeuillez indiquer l'horaire d'arrivée pour pouvoir ajouter une photo."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    _showAddMediaPopup(childId);
  }

  Future<void> _addMediaToFirebase(String childId, String mediaUrl,
      {String type = 'Photo'}) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference mediaRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('medias')
          .doc();

      final mediaData = {
        'heure': _mediaTime.isEmpty
            ? DateFormat('HH:mm').format(DateTime.now())
            : _mediaTime,
        'date': DateTime.now(),
        'type': type,
        'url': mediaUrl,
      };

      await mediaRef.set(mediaData);
      print("Média ajouté avec succès ! type=$type");
    } catch (e) {
      print("Erreur lors de l'ajout de la photo : $e");
      throw e;
    }
  }

  void _showMediaDetailsPopup(Map<String, dynamic> mediaData) {
    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal:
                isTabletDevice ? MediaQuery.of(context).size.width * 0.25 : 20,
            vertical: 20,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 500,
              minWidth: 250,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête avec dégradé
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor,
                          primaryColor.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            (mediaData['type'] == 'Video')
                                ? Icons.videocam
                                : Icons.photo,
                            color: Colors.white,
                            size: isTabletDevice ? 30 : 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${mediaData['type'] == 'Video' ? 'Vidéo' : 'Photo'} de ${mediaData['heure']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(mediaData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bouton supprimer (même UX que Repas/Activités/Siestes)
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () {
                            _confirmDeleteMedia(context, mediaData);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Contenu - Image/Vidéo
                  Padding(
                    padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (mediaData['type'] == 'Video')
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_filled,
                                      size: 64, color: primaryColor),
                                  SizedBox(height: 8),
                                  Text('Aperçu vidéo non intégré'),
                                  SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final url = Uri.parse(mediaData['url']);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(Icons.open_in_new),
                                    label: Text('Ouvrir la vidéo'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                mediaData['url'],
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          primaryColor),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image,
                                          size: 64, color: primaryRed),
                                      SizedBox(height: 8),
                                      Text('Erreur de chargement de l\'image'),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),

                        // Bouton Fermer
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              "FERMER",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 16 : 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
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
      },
    );
  }

  // Confirmation & suppression d'un média (photo/vidéo)
  void _confirmDeleteMedia(
      BuildContext dialogContext, Map<String, dynamic> mediaData) {
    final String? structureId = mediaData['structureId'] as String?;
    final String? childId = mediaData['childId'] as String?;
    final String? mediaId = mediaData['id'] as String?;

    if (structureId == null || childId == null || mediaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Impossible de supprimer ce média (identifiants manquants).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: dialogContext,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Supprimer ce média ?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Cette action retirera la photo/vidéo du journal, du récapitulatif et du fil des parents pour la journée.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Annuler'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('structures')
                                .doc(structureId)
                                .collection('children')
                                .doc(childId)
                                .collection('medias')
                                .doc(mediaId)
                                .delete();

                            // Tenter de supprimer aussi le fichier du Storage si URL présente
                            final url = mediaData['url'] as String?;
                            if (url != null && url.isNotEmpty) {
                              try {
                                await FirebaseStorage.instance
                                    .refFromURL(url)
                                    .delete();
                              } catch (_) {
                                // Ignorer les erreurs de suppression Storage
                              }
                            }

                            if (Navigator.of(ctx).canPop())
                              Navigator.of(ctx).pop();
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Média supprimé.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la suppression du média.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Avatar par défaut avec l'initiale du prénom
  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color avatarColor = (genre == 'Fille') ? primaryRed : primaryBlue;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Utilisation de l'avatar avec dégradé comme dans HomeScreen
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [avatarColor.withOpacity(0.7), avatarColor],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enfant['prenom'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: primaryColor, size: 24),
                  ),
                  onPressed: () => _guardAddMedia(
                      enfant['structureId'] ??
                          FirebaseAuth.instance.currentUser?.uid,
                      enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des photos
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('medias')
                .where('date',
                    isGreaterThanOrEqualTo: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ))
                .where('date',
                    isLessThan: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ).add(Duration(days: 1)))
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();

              final medias = snapshot.data!.docs;

              if (medias.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Aucune photo enregistrée aujourd'hui",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: medias.length,
                separatorBuilder: (context, index) => SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final doc = medias[idx];
                  final mediaData = doc.data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showMediaDetailsPopup({
                      ...mediaData,
                      'id': doc.id,
                      'childId': enfant['id'],
                      'structureId': enfant['structureId'] ??
                          FirebaseAuth.instance.currentUser?.uid,
                    }),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              (mediaData['type'] == 'Video')
                                  ? Icons.videocam
                                  : Icons.photo,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaData['heure'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  mediaData['type'] ?? "Photo",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Photos.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.photo_camera,
              size: 80,
              color: primaryColor.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun enfant prévu aujourd\'hui',
            style: TextStyle(
              fontSize: 18,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/exchanges');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    return SwipeNavigationWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ✨ NOUVEAU : CommonAppBar remplace _buildAppBar(context)
            CommonAppBar(
              title: 'Photos',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Photos.png',
              primaryColor: primaryBlue,
            ),

            // 🔄 GARDÉ IDENTIQUE : tout votre contenu existant
            // Ajouter le sélecteur de date
            _buildDateSelector(),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                      ),
                    )
                  : _showingPastPhotos
                      ? _buildPastPhotosView(isTabletDevice)
                      : enfants.isEmpty
                          ? _buildEmptyState()
                          : Stack(
                              children: [
                                isTabletDevice
                                    ? _buildTabletLayout()
                                    : ListView.builder(
                                        itemCount: enfants.length,
                                        itemBuilder: _buildEnfantCard,
                                      ),
                                if (_isUploadingFile)
                                  Container(
                                    color: Colors.black.withOpacity(0.5),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: (_uploadProgress > 0 &&
                                                    _uploadProgress <= 1)
                                                ? _uploadProgress
                                                : null,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            _isVideoSelected
                                                ? "Téléchargement de la vidéo..."
                                                : "Envoi des photos...",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    isTabletDevice ? 20 : 18),
                                          ),
                                          if (_uploadProgress > 0)
                                            SizedBox(height: 8),
                                          if (_uploadProgress > 0)
                                            Text(
                                              '${(_uploadProgress * 100).toStringAsFixed(0)} %',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize:
                                                    isTabletDevice ? 16 : 14,
                                              ),
                                            )
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
            )
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Message d'avertissement à gauche
          Expanded(
            flex: 2,
            child: _buildDataRetentionWarning(),
          ),

          // Bouton pour revenir aux photos du jour
          if (_showingPastPhotos)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showingPastPhotos = false;
                  _selectedDate = DateTime.now();
                });
              },
              icon: Icon(Icons.today, color: primaryBlue),
              label: Text(
                "Aujourd'hui",
                style:
                    TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),

          Spacer(),

          // Sélecteur de date
          TextButton.icon(
            onPressed: () => _showDatePicker(),
            icon: Icon(
              Icons.calendar_today,
              color: _showingPastPhotos ? primaryBlue : Colors.grey.shade600,
            ),
            label: Text(
              _showingPastPhotos
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(_selectedDate)
                  : "Historique des photos",
              style: TextStyle(
                color: _showingPastPhotos ? primaryBlue : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _showingPastPhotos
                  ? primaryBlue.withOpacity(0.1)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRetentionWarning() {
    final bool isTabletDevice = isTablet(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTabletDevice ? 12 : 10,
        vertical: isTabletDevice ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: isTabletDevice ? 16 : 14,
            color: Colors.grey.shade600,
          ),
          SizedBox(width: isTabletDevice ? 8 : 6),
          Flexible(
            child: Text(
              "Photos conservées 10 jours",
              style: TextStyle(
                fontSize: isTabletDevice ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now.subtract(
        Duration(days: 9)); // 9 jours en arrière (+ aujourd'hui = 10 jours)

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _showingPastPhotos ? _selectedDate : now.subtract(Duration(days: 1)),
      firstDate: firstDate,
      lastDate: now.subtract(Duration(days: 1)), // Exclure aujourd'hui
      locale: Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _showingPastPhotos = true;
      });
      await _loadPastPhotos(picked);
    }
  }

  Future<void> _loadPastPhotos(DateTime date) async {
    setState(() => _loadingPastPhotos = true);

    try {
      final structureContext = await StructureResolver().resolve();
      final String structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final String structureType = structureContext.normalizedStructureType;
      final bool allowAllChildren = structureContext.showAllChildren;

      // Définir la plage de dates pour le jour sélectionné
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // MODIFICATION: Récupérer d'abord tous les enfants et appliquer le même filtre que _loadEnfantsDuJour
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Appliquer le même filtrage que dans _loadEnfantsDuJour
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == 'mam') {
        if (allowAllChildren) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
              "📸 Photos passées: Membre MAM - chargement des photos pour tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "📸 Photos passées: Membre MAM - chargement des photos pour ${filteredChildren.length} enfant(s) assigné(s)");
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants
        filteredChildren = allChildren;
        print(
            "📸 Photos passées: Assistante Maternelle - chargement des photos pour tous les enfants");
      }

      List<Map<String, dynamic>> allPhotos = [];

      // Charger les photos SEULEMENT pour les enfants filtrés
      for (var enfant in filteredChildren) {
        final photosSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(enfant['id'])
            .collection('medias')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where('date', isLessThan: endOfDay.add(Duration(days: 1)))
            .orderBy('date', descending: true)
            .get();

        for (var doc in photosSnapshot.docs) {
          final data = doc.data();
          allPhotos.add({
            ...data,
            'id': doc.id,
            'childId': enfant['id'],
            'childName': enfant[
                'firstName'], // Utiliser firstName comme dans les autres endroits
            'childGender': enfant['gender'],
            'structureId': structureId,
          });
        }
      }

      // Trier par heure
      allPhotos.sort((a, b) {
        final timeA = a['heure'] ?? '00:00';
        final timeB = b['heure'] ?? '00:00';
        return timeB.compareTo(timeA); // Ordre décroissant
      });

      setState(() {
        _pastPhotos = allPhotos;
        _loadingPastPhotos = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des photos passées: $e");
      setState(() => _loadingPastPhotos = false);
    }
  }

  Widget _buildPastPhotosView(bool isTabletDevice) {
    if (_loadingPastPhotos) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }

    if (_pastPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune photo trouvée',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'pour le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return isTabletDevice ? _buildPastPhotosGrid() : _buildPastPhotosList();
  }

// Grille pour tablette
  Widget _buildPastPhotosGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _pastPhotos.length,
      itemBuilder: (context, index) =>
          _buildPastPhotoCard(_pastPhotos[index], true),
    );
  }

// Liste pour mobile
  Widget _buildPastPhotosList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pastPhotos.length,
      itemBuilder: (context, index) =>
          _buildPastPhotoCard(_pastPhotos[index], false),
    );
  }

// Carte pour une photo passée
  Widget _buildPastPhotoCard(Map<String, dynamic> photo, bool isGrid) {
    final Color childColor =
        (photo['childGender'] == 'Fille') ? primaryRed : primaryBlue;

    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec info enfant
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [childColor.withOpacity(0.8), childColor],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: isGrid ? 30 : 40,
                  height: isGrid ? 30 : 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      photo['childName'][0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isGrid ? 14 : 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo['childName'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isGrid ? 12 : 14,
                        ),
                      ),
                      if (!isGrid)
                        Text(
                          photo['heure'] ?? 'Heure inconnue',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Média (photo/vidéo)
          Expanded(
            child: GestureDetector(
              onTap: () => _showMediaDetailsPopup(photo),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (photo['type'] == 'Video')
                      ? Container(
                          color: Colors.black12,
                          child: Center(
                            child: Icon(Icons.play_circle_fill,
                                size: 48, color: primaryBlue),
                          ),
                        )
                      : Image.network(
                          photo['url'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryBlue),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: Colors.grey.shade200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    color: Colors.grey.shade400),
                                if (!isGrid)
                                  Text('Erreur de chargement',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Heure pour la grille
          if (isGrid)
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                photo['heure'] ?? 'Heure inconnue',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

// Nouvelle méthode pour construire la mise en page en grille pour iPad
  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

// Nouvelle carte enfant optimisée pour iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color avatarColor = (genre == 'Fille') ? primaryRed : primaryBlue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec gradient et infos enfant
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [avatarColor, avatarColor.withOpacity(0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar avec photo de l'enfant
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            width: 65,
                            height: 65,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Bouton d'ajout de photo
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: avatarColor, size: 24),
                      onPressed: () => _guardAddMedia(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id']),
                      tooltip: "Ajouter une photo",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des photos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('medias')
                  .where('date',
                      isGreaterThanOrEqualTo: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ))
                  .where('date',
                      isLessThan: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ).add(Duration(days: 1)))
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container();

                final medias = snapshot.data!.docs;

                if (medias.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Aucune photo enregistrée aujourd'hui",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: BouncingScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.all(16),
                  itemCount: medias.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final doc = medias[idx];
                    final mediaData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showMediaDetailsPopup({
                        ...mediaData,
                        'id': doc.id,
                        'childId': enfant['id'],
                        'structureId': enfant['structureId'] ??
                            FirebaseAuth.instance.currentUser?.uid,
                      }),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lightBlue),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.photo,
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mediaData['heure'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    mediaData['type'] ?? "Photo",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Avatar par défaut plus grand pour iPad
  Widget _buildFallbackAvatarForTablet(String name) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  // Navigation du bas
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryBlue,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Dashboard.png',
            width: 60,
            height: 60,
          ),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/maison_icon.png',
            width: 60,
            height: 60,
          ),
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Echanges.png',
            width: 60,
            height: 60,
          ),
          label: "Messages",
        ),
      ],
    );
  }
}
