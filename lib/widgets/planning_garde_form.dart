import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/models/garde_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';

class PlanningGardeForm extends StatefulWidget {
  final Garde? garde;
  final List<Enfant> enfants;
  final Membre membre;
  final Function(Garde) onSave;

  const PlanningGardeForm({
    Key? key,
    this.garde,
    required this.enfants,
    required this.membre,
    required this.onSave,
  }) : super(key: key);

  @override
  _PlanningGardeFormState createState() => _PlanningGardeFormState();
}

class _PlanningGardeFormState extends State<PlanningGardeForm> {
  final _formKey = GlobalKey<FormState>();

  late String _enfantId;
  late int _jourSemaine;
  late TimeOfDay _heureDebut;
  late TimeOfDay _heureFin;
  late bool _recurrent;
  DateTime? _dateException;

  static const Color primaryBlue = Color(0xFF3D9DF2);
  late Color primaryColor = primaryBlue;

  @override
  void initState() {
    super.initState();

    // Initialiser avec les valeurs de la garde existante ou des valeurs par défaut
    if (widget.garde != null) {
      _enfantId = widget.garde!.enfantId;
      _jourSemaine = widget.garde!.jourSemaine;
      _heureDebut = _parseHeure(widget.garde!.heureDebut);
      _heureFin = _parseHeure(widget.garde!.heureFin);
      _recurrent = widget.garde!.recurrent;
      _dateException = widget.garde!.dateException;
    } else {
      // Valeurs par défaut pour une nouvelle garde
      _enfantId = widget.enfants.isNotEmpty ? widget.enfants.first.id : '';
      _jourSemaine = 1; // Lundi
      _heureDebut = TimeOfDay(hour: 8, minute: 0);
      _heureFin = TimeOfDay(hour: 17, minute: 0);
      _recurrent = true;
      _dateException = null;
    }
  }

  TimeOfDay _parseHeure(String heure) {
    final parts = heure.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatHeure(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _heureDebut : _heureFin,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _heureDebut = picked;
        } else {
          _heureFin = picked;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateException ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dateException = picked;
      });
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      // Vérifier que l'heure de fin est après l'heure de début
      if (_heureDebut.hour > _heureFin.hour ||
          (_heureDebut.hour == _heureFin.hour &&
              _heureDebut.minute >= _heureFin.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("L'heure de fin doit être après l'heure de début"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Vérifier que la date d'exception est fournie si non récurrent
      if (!_recurrent && _dateException == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Veuillez sélectionner une date spécifique"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Créer la garde
      final garde = Garde(
        id: widget.garde?.id ?? '',
        enfantId: _enfantId,
        membreId: widget.membre.id,
        mamId: widget.membre.mamId,
        jourSemaine: _jourSemaine,
        heureDebut: _formatHeure(_heureDebut),
        heureFin: _formatHeure(_heureFin),
        recurrent: _recurrent,
        dateException: !_recurrent ? _dateException : null,
      );

      // Appeler la fonction de sauvegarde
      widget.onSave(garde);

      // Fermer le formulaire
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.garde == null ? 'Ajouter une garde' : 'Modifier la garde',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Sélection de l'enfant
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Enfant',
                border: OutlineInputBorder(),
              ),
              value: _enfantId,
              items: widget.enfants.map((enfant) {
                return DropdownMenuItem<String>(
                  value: enfant.id,
                  child: Text('${enfant.prenom} ${enfant.nom}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _enfantId = value;
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner un enfant';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Sélection du jour de la semaine
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Jour',
                border: OutlineInputBorder(),
              ),
              value: _jourSemaine,
              items: [
                DropdownMenuItem(value: 1, child: Text('Lundi')),
                DropdownMenuItem(value: 2, child: Text('Mardi')),
                DropdownMenuItem(value: 3, child: Text('Mercredi')),
                DropdownMenuItem(value: 4, child: Text('Jeudi')),
                DropdownMenuItem(value: 5, child: Text('Vendredi')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _jourSemaine = value;
                  });
                }
              },
            ),
            SizedBox(height: 16),

            // Sélection des heures
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Heure de début',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatHeure(_heureDebut)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Heure de fin',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatHeure(_heureFin)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Option récurrente ou exceptionnelle
            CheckboxListTile(
              title: Text('Récurrent chaque semaine'),
              value: _recurrent,
              onChanged: (value) {
                setState(() {
                  _recurrent = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Date d'exception (visible uniquement si non récurrent)
            if (!_recurrent)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date spécifique',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dateException != null
                          ? DateFormat('dd/MM/yyyy').format(_dateException!)
                          : 'Sélectionner une date',
                    ),
                  ),
                ),
              ),

            SizedBox(height: 24),

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _handleSubmit,
                  child: Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
