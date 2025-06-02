import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  final _db = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Stream que devolve true / false consoante o utilizador é admin
  Stream<bool> get isAdminStream => _db
      .child('users/$_uid/role')
      .onValue
      .map((e) => (e.snapshot.value ?? 'user') == 'admin');

  /// Lista de crops atribuídas ao user
  Future<List<String>> myCropIds() async {
    final snap = await _db.child('users/$_uid/crops').get();
    if (!snap.exists) return [];
    return List<String>.from(snap.value as List);
  }
}
