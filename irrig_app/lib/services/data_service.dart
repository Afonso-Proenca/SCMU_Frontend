import 'package:firebase_database/firebase_database.dart';

class DataService {
  // ---------------- base ----------------
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  DatabaseReference get db => _db;           // usado no AdminPage

  List<SensorData> _lastHourSensorData = [];

  // ---------------- crops ----------------
  Stream<Iterable<Crop>> cropsStream() => _db
      .child('crops')
      .onValue
      .map((event) {
        final raw = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        return raw.entries.map((e) {
          final data = Map<String, dynamic>.from(e.value);
          return Crop.fromMap(e.key.toString(), data);
        });
      });

  Future<void> addCrop(
    String name,
    String type,
    Map<String, Map<String, double>> settings,
  ) async {
    final payload = <String, dynamic>{
      'name': name,
      'type': type,
    };
    if (settings.isNotEmpty) payload['settings'] = settings;
    await _db.child('crops').push().set(payload);
  }

  Future<void> deleteCrop(String id) =>
      _db.child('crops/$id').remove();

  // ---------------- users ----------------
  Stream<Iterable<UserInfoDB>> usersStream() => _db
      .child('users')
      .onValue
      .map((event) {
        final raw = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        return raw.entries.map((e) {
          // converte para Map<String,dynamic> salvaguardando tipos
          final m = (e.value as Map).map(
            (k, v) => MapEntry(k.toString(), v),
          );
          return UserInfoDB.fromMap(e.key.toString(), m);
        });
      });

  // ---------------- irrigation settings ----------------
  Future<IrrigationSettings> getSettings() async {
    final snap = await _db.child('settings').get();
    if (!snap.exists) {
      return IrrigationSettings(moistMin: 20, moistMax: 60);
    }
    return IrrigationSettings.fromMap(
        Map<String, dynamic>.from(snap.value as Map));
  }

  Future<void> saveSettings(IrrigationSettings s) =>
      _db.child('settings').set(s.toMap());

  // ---------------- water tank ----------------
  Stream<WaterTankInfo> tankStream() => _db
      .child('water_tank')
      .onValue
      .map((e) => WaterTankInfo.fromMap(
          Map<String, dynamic>.from(e.snapshot.value as Map)));

  // ---------------- sensor data ----------------
  Stream<List<SensorData>> lastHourSensorDataStream() => _db
      .child('sensordata')
      .onValue
      .map((event) {
        final now = DateTime.now().subtract(const Duration(hours: 1));
        final raw = event.snapshot.value as Map<dynamic, dynamic>? ?? {};

        final list = raw.entries
            .map((e) => SensorData.fromMap(e.key.toString(),
                Map<String, dynamic>.from(e.value)))
            .where((d) => d.timestamp.isAfter(now))
            .toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        _lastHourSensorData = list;
        return list;
      });

  List<SensorData> getLastHourDataCache() => _lastHourSensorData;
}

/* ========== MODELOS ========== */

class Crop {
  final String id;
  final String name;
  final String type;
  final Map<String, Map<String, double>> settings;

  Crop(this.id, this.name, this.type, this.settings);

  factory Crop.fromMap(String id, Map<String, dynamic> m) {
    final settings = <String, Map<String, double>>{};
    if (m['settings'] != null) {
      final raw = m['settings'] as Map<dynamic, dynamic>;
      raw.forEach((key, value) {
        settings[key.toString()] = Map<String, double>.from(
          (value as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        );
      });
    }
    return Crop(id, m['name'], m['type'], settings);
  }
}

class UserInfoDB {
  final String uid;
  final String? name;
  final List<String> crops;

  UserInfoDB({required this.uid, this.name, required this.crops});

  factory UserInfoDB.fromMap(String uid, Map<String, dynamic> m) {
    final rawList = m['crops'] as List<dynamic>? ?? [];
    return UserInfoDB(
      uid: uid,
      name: m['name']?.toString(),
      crops: rawList.map((e) => e.toString()).toList(),
    );
  }
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
  final double level;
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
  factory SensorData.fromMap(String key, Map<String, dynamic> m) => SensorData(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(int.tryParse(key) ?? 0),
        moisture: (m['moisture'] as num).toDouble(),
        temperature: (m['temperature'] as num).toDouble(),
      );
}
