import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

class IrrigationSettingsPage extends StatefulWidget {
  const IrrigationSettingsPage({Key? key}) : super(key: key);

  @override
  State<IrrigationSettingsPage> createState() => _IrrigationSettingsPageState();
}

class _IrrigationSettingsPageState extends State<IrrigationSettingsPage> {
  double _min = 20, _max = 60;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final ds = context.read<DataService>();
    ds.getSettings().then((s) {
      setState(() {
        _min = s.moistMin;
        _max = s.moistMax;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Irrigation Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text('Soil moisture min: ${_min.toStringAsFixed(0)} %'),
                  Slider(
                    value: _min,
                    min: 0,
                    max: _max - 5,
                    divisions: 20,
                    label: _min.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _min = v),
                  ),
                  const SizedBox(height: 16),
                  Text('Soil moisture max: ${_max.toStringAsFixed(0)} %'),
                  Slider(
                    value: _max,
                    min: _min + 5,
                    max: 100,
                    divisions: 20,
                    label: _max.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _max = v),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      await ds.saveSettings(
                          IrrigationSettings(moistMin: _min, moistMax: _max));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved!')));
                    },
                    child: const Text('Save'),
                  )
                ],
              ),
            ),
    );
  }
}
