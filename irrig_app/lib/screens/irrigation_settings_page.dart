import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';

class IrrigationSettingsPage extends StatefulWidget {
  const IrrigationSettingsPage({Key? key}) : super(key: key);

  @override
  State<IrrigationSettingsPage> createState() => _IrrigationSettingsPageState();
}

class _IrrigationSettingsPageState extends State<IrrigationSettingsPage> {
  Crop? _selectedCrop;

  // controllers partilhados
  final _humMin = TextEditingController();
  final _humMax = TextEditingController();
  final _tempMin = TextEditingController();
  final _tempMax = TextEditingController();
  final _lightMin = TextEditingController();
  final _lightMax = TextEditingController();

  @override
  void dispose() {
    _humMin.dispose();
    _humMax.dispose();
    _tempMin.dispose();
    _tempMax.dispose();
    _lightMin.dispose();
    _lightMax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final us = context.read<UserService>();

    return FutureBuilder<List<String>>(
      future: us.myCropIds(),
      builder: (context, futureSnap) {
        if (futureSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allowedList = futureSnap.data ?? <String>[];

        return Scaffold(
          appBar: AppBar(title: const Text('Irrigation Settings')),
          body: StreamBuilder<Iterable<Crop>>(
            stream: ds.cropsStream(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final crops = snap.data!.toList();
              if (crops.isEmpty) {
                return const Center(child: Text('No crops found'));
              }

              // ---- sincroniza _selectedCrop com a lista que acabou de chegar ----
              if (_selectedCrop == null) {
                _selectedCrop = crops.first;
              } else {
                final match = crops
                    .where((c) => c.id == _selectedCrop!.id)
                    .toList(); // 0 ou 1
                _selectedCrop = match.isNotEmpty ? match.first : crops.first;
              }
              return StreamBuilder<bool>(
                stream: us.isAdminStream,
                initialData: true,
                builder: (context, adminSnap) {
                  final bool isAdmin = adminSnap.data ?? false;
                  final bool isAssigned =
                      allowedList.contains(_selectedCrop!.id);

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: [
                        DropdownButtonFormField<Crop>(
                          value: _selectedCrop,
                          items: crops
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c.name)))
                              .toList(),
                          onChanged: (c) {
                            if (c == null) return;
                            setState(() => _selectedCrop = c);
                            _populateControllers(c);
                          },
                          decoration:
                              const InputDecoration(labelText: 'Select crop'),
                        ),
                        const SizedBox(height: 16),
                        if (!isAdmin && !isAssigned)
                          Column(
                            children: const [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'You are not assigned to this crop. Fields are disabled.',
                                style: TextStyle(color: Colors.orange),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        _rangeField('Humidity Min (%)', _humMin,
                            isEnabled: isAssigned || isAdmin),
                        _rangeField('Humidity Max (%)', _humMax,
                            isEnabled:isAssigned || isAdmin),
                        _rangeField('Temperature Min (°C)', _tempMin,
                            isEnabled: isAssigned || isAdmin),
                        _rangeField('Temperature Max (°C)', _tempMax,
                            isEnabled: isAssigned || isAdmin),
                        _rangeField('Light Min (lux)', _lightMin,
                            isEnabled: isAssigned || isAdmin),
                        _rangeField('Light Max (lux)', _lightMax,
                            isEnabled: isAssigned || isAdmin),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _selectedCrop == null
                              ? null
                              : () async {
                                  final settings = {
                                    'humidity': {
                                      'min': double.tryParse(_humMin.text) ?? 0,
                                      'max': double.tryParse(_humMax.text) ?? 0,
                                    },
                                    'temperature': {
                                      'min':
                                          double.tryParse(_tempMin.text) ?? 0,
                                      'max':
                                          double.tryParse(_tempMax.text) ?? 0,
                                    },
                                    'light': {
                                      'min':
                                          double.tryParse(_lightMin.text) ?? 0,
                                      'max':
                                          double.tryParse(_lightMax.text) ?? 0,
                                    },
                                  };

                                  await ds.updateCropSettings(
                                      _selectedCrop!.id, settings);

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Settings saved')),
                                    );
                                  }
                                },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ---------- helpers ----------
  void _populateControllers(Crop c) {
    final hum = c.settings['humidity'] ?? {};
    final temp = c.settings['temperature'] ?? {};
    final light = c.settings['light'] ?? {};
    _humMin.text = (hum['min'] ?? '').toString();
    _humMax.text = (hum['max'] ?? '').toString();
    _tempMin.text = (temp['min'] ?? '').toString();
    _tempMax.text = (temp['max'] ?? '').toString();
    _lightMin.text = (light['min'] ?? '').toString();
    _lightMax.text = (light['max'] ?? '').toString();
  }

  Widget _rangeField(String label, TextEditingController ctrl,
          {required bool isEnabled}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          enabled: isEnabled,
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
}
