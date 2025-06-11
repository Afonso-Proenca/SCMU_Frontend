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
            .map((e) => Crop.fromMap(
                e.key as String, Map<String, dynamic>.from(e.value))),
      );

  Future<void> addCrop(
      String name,
      String type,
      Map<String, Map<String, double>> settings,
      ) async {
      if (name.trim().isEmpty) {
        throw ArgumentError('Crop name cannot be empty');
      }
    final ref = _db.child('crops').push();

    // Começamos pelos dados introduzidos pelo utilizador
    Map<String, Map<String, double>> finalSettings = {...settings};

    // Se não for “custom”, tentamos ler defaults
    if (type != 'custom') {
      final defaultSnap = await _db.child('crops_default/$type').get();
      if (defaultSnap.exists) {
        final defaultsRaw = Map<String, dynamic>.from(defaultSnap.value as Map);
        final defaultSettings =
        (defaultsRaw['settings'] as Map).map((k, v) => MapEntry(
          k.toString(),
          (v as Map).map(
                  (sk, sv) => MapEntry(sk.toString(), (sv as num).toDouble())),
        ));

        // merge → defaults primeiro, depois valores que o utilizador tenha
        // preenchido (só substitui se o utilizador não deixou em branco/0)
        defaultSettings.forEach((sensor, ranges) {
          final merged = Map<String, double>.from(ranges);
          final userRanges = finalSettings[sensor] ?? {};
          userRanges.forEach((key, val) {
            if (val != 0) merged[key] = val;
          });
          finalSettings[sensor] = merged;
        });
      }
    }

    await ref.set({
      'name': name,
      'type': type,
      'settings': finalSettings,
    });
  }




  Future<void> updateCropSettings(
      String cropId,
      Map<String, Map<String, double>> settings,
      ) {
    return _db.child('crops/$cropId/settings').set(settings);
  }

  Future<void> deleteCrop(String id) async {
    await _db.child('crops/$id').remove();

    final userSnap = await _db.child('users').get();
    if (!userSnap.exists) return;

    final users = Map<String, dynamic>.from(userSnap.value as Map);

    for (final entry in users.entries) {
      final uid = entry.key;
      final userData = Map<String, dynamic>.from(entry.value as Map);

      if (userData.containsKey('crops')) {
        final cropsList = List<dynamic>.from(userData['crops'] as List);

        final newCropsList = cropsList.where((cropEntry) {
          final cropMap = Map<String, dynamic>.from(cropEntry as Map);
          return cropMap['id'] != id;
        }).toList();

        if (newCropsList.length != cropsList.length) {
          await _db.child('users/$uid/crops').set(newCropsList);
        }
      }
    }
  }


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




 // ---------- Sensor data ----------
  Stream<List<SensorData>> lastHourSensorDataStream(String cropId, String cropType) {
    final path = 'crops/$cropId/sensors';

    //acumular dados do server
    final List<SensorData> history = [];

    return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
      final snapshot = await _db.child(path).get();

      if (snapshot.value == null) return history;

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      final now = DateTime.now();
      final timestampMillis = now.millisecondsSinceEpoch;

      //cria sensor data acrescentando o timestamp
      final newData = SensorData(
        id: timestampMillis.toString(),
        timestamp: now,
        temperature: (data['temperature'] as num).toDouble(),
        moisture: (data['humidity'] as num).toDouble(),
        light: (data['light'] as num).toDouble(),
      );

      print('New SensorData: ${newData.timestamp} → temp=${newData.temperature}, hum=${newData.moisture}, light=${newData.light}');

      history.add(newData);

      // guarda ultima hora (não sei se é preciso mais)
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      history.removeWhere((d) => d.timestamp.isBefore(oneHourAgo));
      history.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return List<SensorData>.from(history);
    });
  }

  List<SensorData> getLastHourDataCache() => _lastHourSensorData;
}
/// --- modelos simples ---

class Crop {
  final String id, name, type;
  final Map<String, Map<String, double>> settings;

  Crop(this.id, this.name, this.type, this.settings);

  factory Crop.fromMap(String id, Map<String, dynamic> m) {
    return Crop(
      id,
      m['name'] as String,
      m['type'] as String,
      Map<String, Map<String, double>>.from(
        (m['settings'] as Map? ?? {}).map((k, v) {
          final inner = Map<String, dynamic>.from(v as Map);
          final converted = inner.map(
                (ik, iv) => MapEntry(ik.toString(), (iv as num).toDouble()),
          );
          return MapEntry(k.toString(), converted);
        }),
      ),
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
  final double level; // percentual
  final bool pumpOn;

  WaterTankInfo({required this.level, required this.pumpOn});

  factory WaterTankInfo.fromMap(Map<String, dynamic> m) {
    final rawDist = (m['level'] as num).toDouble();
    final pct = ((1 / rawDist) - (1 / 12)) * 400;
    return WaterTankInfo(
      level: pct.clamp(0, 100),
      pumpOn: m['pumpOn'] == true,
    );
  }
}

class SensorData {
  final String id;
  final DateTime timestamp;
  final double temperature;
  final double moisture;
  final double light;

  SensorData({
    required this.id,
    required this.timestamp,
    required this.temperature,
    required this.moisture,
    required this.light,
  });

}

