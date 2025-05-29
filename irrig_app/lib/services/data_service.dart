import 'package:firebase_database/firebase_database.dart';

class DataService {
  final _db = FirebaseDatabase.instance.ref();

  // ---------- Crops ----------
  Stream<Iterable<Crop>> cropsStream() => _db.child('crops').onValue.map(
        (event) => (event.snapshot.value as Map<dynamic, dynamic>? ?? {})
            .entries
            .map((e) => Crop.fromMap(e.key, Map<String, dynamic>.from(e.value))),
      );

  Future<void> addCrop(String name, String type) async {
    await _db.child('crops').push().set({'name': name, 'type': type});
  }

  Future<void> deleteCrop(String id) => _db.child('crops/$id').remove();

  // ---------- Irrigation Settings ----------
  Future<IrrigationSettings> getSettings() async {
    final snap = await _db.child('settings').get();
    return IrrigationSettings.fromMap(
        Map<String, dynamic>.from(snap.value as Map));
  }

  Future<void> saveSettings(IrrigationSettings s) async {
    await _db.child('settings').set(s.toMap());
  }

  // ---------- Water Tank ----------
  Stream<WaterTankInfo> tankStream() => _db
      .child('water_tank')
      .onValue
      .map((e) => WaterTankInfo.fromMap(
          Map<String, dynamic>.from(e.snapshot.value as Map)));
}

/* --- modelos simples --- */
class Crop {
  final String id, name, type;
  Crop(this.id, this.name, this.type);
  factory Crop.fromMap(String id, Map<String, dynamic> m) =>
      Crop(id, m['name'], m['type']);
}

class IrrigationSettings {
  final double moistMin, moistMax;
  IrrigationSettings({required this.moistMin, required this.moistMax});
  factory IrrigationSettings.fromMap(Map<String, dynamic> m) =>
      IrrigationSettings(moistMin: m['min'] * 1.0, moistMax: m['max'] * 1.0);
  Map<String, dynamic> toMap() => {'min': moistMin, 'max': moistMax};
}

class WaterTankInfo {
  final double level; // %
  final bool pumpOn;
  WaterTankInfo({required this.level, required this.pumpOn});
  factory WaterTankInfo.fromMap(Map<String, dynamic> m) =>
      WaterTankInfo(level: m['level'] * 1.0, pumpOn: m['pumpOn'] == true);
}
