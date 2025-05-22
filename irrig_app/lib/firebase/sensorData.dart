import 'package:firebase_database/firebase_database.dart';

class SensorDataService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<Map<String, dynamic>?> getSensorData(String path) async {
    print(_database.toString());
    final snapshot = await _database.child(path).get();
    if (snapshot.exists && snapshot.value != null) {
      final value = snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  Stream<Map<String, dynamic>?> streamSensorData(String path) {
    return _database.child(path).onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        if (value is Map) {
          return Map<String, dynamic>.from(value);
        }
      }
      return null;
    });
  }
}
