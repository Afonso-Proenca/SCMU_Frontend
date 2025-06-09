import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

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

          // primeira selecção
          _selectedCrop ??= crops.first;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                DropdownButtonFormField<Crop>(
                  value: _selectedCrop,
                  items: crops
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (c) {
                    if (c == null) return;
                    setState(() => _selectedCrop = c);
                    _populateControllers(c);
                  },
                  decoration: const InputDecoration(labelText: 'Select crop'),
                ),
                const SizedBox(height: 16),
                _rangeField('Humidity Min (%)', _humMin),
                _rangeField('Humidity Max (%)', _humMax),
                _rangeField('Temperature Min (°C)', _tempMin),
                _rangeField('Temperature Max (°C)', _tempMax),
                _rangeField('Light Min (lux)', _lightMin),
                _rangeField('Light Max (lux)', _lightMax),
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
                        'min': double.tryParse(_tempMin.text) ?? 0,
                        'max': double.tryParse(_tempMax.text) ?? 0,
                      },
                      'light': {
                        'min': double.tryParse(_lightMin.text) ?? 0,
                        'max': double.tryParse(_lightMax.text) ?? 0,
                      },
                    };

                    await ds.updateCropSettings(_selectedCrop!.id, settings);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- helpers ----------
  void _populateControllers(Crop c) {
    final hum   = c.settings['humidity']    ?? {};
    final temp  = c.settings['temperature'] ?? {};
    final light = c.settings['light']       ?? {};
    _humMin.text   = (hum['min']   ?? '').toString();
    _humMax.text   = (hum['max']   ?? '').toString();
    _tempMin.text  = (temp['min']  ?? '').toString();
    _tempMax.text  = (temp['max']  ?? '').toString();
    _lightMin.text = (light['min'] ?? '').toString();
    _lightMax.text = (light['max'] ?? '').toString();
  }

  Widget _rangeField(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    ),
  );
}
