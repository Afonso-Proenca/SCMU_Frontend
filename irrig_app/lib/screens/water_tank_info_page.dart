import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';


Widget waterLevelPage(BuildContext context) {
  final db = FirebaseDatabase.instance;

  // RTDB paths
  final DatabaseReference _levelRef = db.ref('/waterLevel');
  final DatabaseReference _pumpStatusRef = db.ref('/water_pump_statusON');

  // ---- Helpers -----------------------------------------------------------
  Future<void> _setPump(bool value) async {
    try {
      await _pumpStatusRef.set(value);           // actualiza RTDB
      // feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Pump turned ON' : 'Pump turned OFF')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $e')),
      );
    }
  }

  Future<void> _activateIrrigation() => _setPump(true);
  Future<void> _deactivateIrrigation() => _setPump(false);

  // ------------------------------------------------------------------------
  return Scaffold(
    appBar: AppBar(
      title: const Text('Water Tank'),
      centerTitle: true,
    ),
    body: StreamBuilder<DatabaseEvent>(
      stream: _levelRef.onValue,
      builder: (context, levelSnap) {
        double level = 0;
        if (levelSnap.hasData && levelSnap.data!.snapshot.value != null) {
          final raw = levelSnap.data!.snapshot.value;
          if (raw is num) level = raw.toDouble().clamp(0, 100);
        }

        // Pump status
        return StreamBuilder<DatabaseEvent>(
          stream: _pumpStatusRef.onValue,
          builder: (context, pumpSnap) {
            bool pumpOn = false;
            if (pumpSnap.hasData && pumpSnap.data!.snapshot.value != null) {
              final v = pumpSnap.data!.snapshot.value;
              if (v is bool) {
                pumpOn = v;
              } else if (v is num) {
                pumpOn = v != 0;
              } else if (v is String) {
                pumpOn = v.toLowerCase() == 'true';
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Level of the water tank',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),

                  // Gauge circular
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 220,
                            width: 220,
                            child: CircularProgressIndicator(
                              value: level / 100,
                              strokeWidth: 16,
                            ),
                          ),
                          Text(
                            '${level.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Pump status indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        pumpOn ? Icons.power : Icons.power_off,
                        color: pumpOn ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pumpOn ? 'Pump ON' : 'Pump OFF',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: pumpOn ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Buttons: Activate & Deactivate
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Activate irrigation'),
                          onPressed: pumpOn ? null : _activateIrrigation,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.stop),
                          label: const Text('Deactivate irrigation'),
                          onPressed: pumpOn ? _deactivateIrrigation : null,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
