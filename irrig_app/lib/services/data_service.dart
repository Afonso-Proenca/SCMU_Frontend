import 'package:firebase_database/firebase_database.dart';

class DataService {
  // Referência raiz do Realtime Database
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  DatabaseReference get db => _db; // Para o AdminPage usar

  List<SensorData> _lastHourSensorData = [];

  // ---------- Crops ----------

  /// Stream contínua de todas as crops
  Stream<Iterable<Crop>> cropsStream() => _db
      .child('crops')
      .onValue
      .map((event) {
    final rawMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    return rawMap.entries.map((e) {
      final data = Map<String, dynamic>.from(e.value);
      return Crop.fromMap(e.key as String, data);
    });
  });

  /// Adiciona uma nova crop. Agora aceita também [settings].
  Future<void> addCrop(
    String name,
    String type,
    Map<String, Map<String, double>> settings,
  ) async {
    final toSet = <String, dynamic>{
      'name': name,
      'type': type,
    };
    if (settings.isNotEmpty) {
      toSet['settings'] = settings;
    }
    await _db.child('crops').push().set(toSet);
  }

  /// Remove a crop pelo ID
  Future<void> deleteCrop(String id) =>
      _db.child('crops/$id').remove();

  // ---------- Users (NOVO) ----------

  /// Stream de todos os utilizadores com informações básicas (uid, nome, lista de crops)
  Stream<Iterable<UserInfoDB>> usersStream() =>
      _db.child('users').onValue.map((event) {
        final rawMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        return rawMap.entries.map((e) {
          final data = Map<String, dynamic>.from(e.value);
          return UserInfoDB.fromMap(e.key as String, data);
        });
      });

  // ---------- Irrigation Settings ----------

  Future<IrrigationSettings> getSettings() async {
    final snap = await _db.child('settings').get();
    if (!snap.exists) {
      return IrrigationSettings(moistMin: 20, moistMax: 60);
    }
    return IrrigationSettings.fromMap(
        Map<String, dynamic>.from(snap.value as Map));
  }

  Future<void> saveSettings(IrrigationSettings s) async =>
      _db.child('settings').set(s.toMap());

  // ---------- Water Tank ----------

  Stream<WaterTankInfo> tankStream() => _db
      .child('water_tank')
      .onValue
      .map((e) =>
          WaterTankInfo.fromMap(Map<String, dynamic>.from(e.snapshot.value as Map)));

  // ---------- Sensor data ----------

  Stream<List<SensorData>> lastHourSensorDataStream() => _db
      .child('sensordata')
      .onValue
      .map((event) {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final dataMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    final filtered = dataMap.entries
        .map((e) {
          final entryMap = Map<String, dynamic>.from(e.value);
          return SensorData.fromMap(e.key as String, entryMap);
        })
        .where((d) => d.timestamp.isAfter(oneHourAgo))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _lastHourSensorData = filtered;
    return filtered;
  });

  List<SensorData> getLastHourDataCache() => _lastHourSensorData;
}

/* ---------- MODELOS ---------- */

/// Representa uma Crop, agora incluindo eventuais `settings`
class Crop {
  final String id;
  final String name;
  final String type;
  final Map<String, Map<String, double>> settings;

  Crop(this.id, this.name, this.type, this.settings);

  factory Crop.fromMap(String id, Map<String, dynamic> m) {
    // Converte o bloco "settings" (se existir) num Map<String, Map<String, double>>
    final settingsMap = <String, Map<String, double>>{};
    if (m['settings'] != null) {
      final rawSettings = m['settings'] as Map<dynamic, dynamic>;
      rawSettings.forEach((key, value) {
        final inner = Map<String, double>.from(
            (value as Map<dynamic, dynamic>).map(
                  (k, v) => MapEntry(k as String, (v as num).toDouble()),
                ));
        settingsMap[key as String] = inner;
      });
    }
    return Crop(
      id,
      m['name'] as String,
      m['type'] as String,
      settingsMap,
    );
  }
}

/// Guardar informações básicas de cada utilizador
class UserInfoDB {
  final String uid;
  final String? name;
  final List<String> crops;

  UserInfoDB(this.uid, {this.name, required this.crops});

  factory UserInfoDB.fromMap(String uid, Map<String, dynamic> m) =>
      UserInfoDB(
        uid,
        name: m['displayName']?.toString(),
        crops: m['crops'] != null
            ? List<String>.from(m['crops'] as List<dynamic>)
            : <String>[],
      );
}

/// Modelo das definições de irrigação
class IrrigationSettings {
  final double moistMin, moistMax;
  IrrigationSettings({required this.moistMin, required this.moistMax});

  factory IrrigationSettings.fromMap(Map<String, dynamic> m) => IrrigationSettings(
        moistMin: (m['min'] as num).toDouble(),
        moistMax: (m['max'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {'min': moistMin, 'max': moistMax};
}

/// Modelo do estado do reservatório de água
class WaterTankInfo {
  final double level;
  final bool pumpOn;
  WaterTankInfo({required this.level, required this.pumpOn});
  factory WaterTankInfo.fromMap(Map<String, dynamic> m) => WaterTankInfo(
        level: (m['level'] as num).toDouble(),
        pumpOn: m['pumpOn'] == true,
      );
}

/// Modelo para dados de sensor (última hora)
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
