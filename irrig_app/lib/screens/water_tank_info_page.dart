import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

class WaterTankInfoPage extends StatelessWidget {
  const WaterTankInfoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Water Tank')),
      body: StreamBuilder<WaterTankInfo>(
        stream: ds.tankStream(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snap.data!;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Level: ${info.level.toStringAsFixed(1)} %',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pump'),
                    Switch(value: info.pumpOn, onChanged: null),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
