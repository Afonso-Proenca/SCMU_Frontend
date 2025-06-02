import 'package:firebase_database/firebase_database.dart';

class DataService {
  // Referência raiz da base de dados
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // GETTER PÚBLICO para permitir usar _db fora desta classe (ex: AdminPage)
  DatabaseReference get db => _db;

  // Cache dos últimos dados de sensor (última hora)
  List<SensorData> _lastHourSensorData = [];

  // ---------- Crops ----------
  Stream<Iterable<Crop>> cropsStream() => _db.child('crops').onValue.map(
        (event) => (event.snapshot.value as Map<dynamic, dynamic>? ?? {})
            .entries
            .map((e) => Crop.fromMap(e.key as String, Map<String, dynamic>.from(e.value))),
      );

  Future<void> addCrop(String name, String type) async {
    await _db.child('crops').push().set({'name': name, 'type': type});
  }

  Future<void> deleteCrop(String id) => _db.child('crops/$id').remove();

  // ---------- Irrigation Settings ----------
  Future<IrrigationSettings> getSettings() async {
    final snap = await _db.child('settings').get();
    if (snap.value == null) {
      return IrrigationSettings(moistMin: 20, moistMax: 60);
    }
    return IrrigationSettings.fromMap(
      Map<String, dynamic>.from(snap.value as Map),
    );
  }

  Future<void> saveSettings(IrrigationSettings s) async {
    await _db.child('settings').set(s.toMap());
  }

  // ---------- Water Tank ----------
  Stream<WaterTankInfo> tankStream() => _db
      .child('water_tank')
      .onValue
      .map((e) => WaterTankInfo.fromMap(
            Map<String, dynamic>.from(e.snapshot.value as Map),
          ));

  // ---------- Sensor data ----------
  Stream<List<SensorData>> lastHourSensorDataStream() {
    return _db.child('sensordata').onValue.map((event) {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      final filtered = data.entries
          .map((entry) => SensorData.fromMap(entry.key as String,
              Map<String, dynamic>.from(entry.value as Map)))
          .where((d) => d.timestamp.isAfter(oneHourAgo))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _lastHourSensorData = filtered;
      print('Received ${filtered.length} sensor entries');
      return filtered;
    });
  }

  List<SensorData> getLastHourDataCache() => _lastHourSensorData;
}


/// --- modelos simples ---

class Crop {
  final String id, name, type;
  Crop(this.id, this.name, this.type);

  factory Crop.fromMap(String id, Map<String, dynamic> m) =>
      Crop(id, m['name'] as String, m['type'] as String);
}

class IrrigationSettings {
  final double moistMin, moistMax;
  IrrigationSettings({required this.moistMin, required this.moistMax});

  factory IrrigationSettings.fromMap(Map<String, dynamic> m) =>
      IrrigationSettings(
        moistMin: (m['min'] as num).toDouble(),
        moistMax: (m['max'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {'min': moistMin, 'max': moistMax};
}

class WaterTankInfo {
  final double level; // percentual
  final bool pumpOn;
  WaterTankInfo({required this.level, required this.pumpOn});

  factory WaterTankInfo.fromMap(Map<String, dynamic> m) => WaterTankInfo(
        level: (m['level'] as num).toDouble(),
        pumpOn: m['pumpOn'] == true,
      );
}

class SensorData {
  final DateTime timestamp;
  final double moisture;
  final double temperature;

  SensorData({
    required this.timestamp,
    required this.moisture,
    required this.temperature,
  });

  factory SensorData.fromMap(String key, Map<String, dynamic> data) {
    return SensorData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.tryParse(key) ?? 0),
      moisture: (data['moisture'] as num).toDouble(),
      temperature: (data['temperature'] as num).toDouble(),
    );
  }
}
