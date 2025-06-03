import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  final _db  = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Stream que devolve true/false conforme 'users/$_uid/role' seja igual a 'admin'.
  Stream<bool> get isAdminStream => _db
      .child('users/$_uid/role')
      .onValue
      .map((event) {
        // Sempre converte para String e minúsculas para evitar "Admin" ≠ "admin"
        final roleValue = event.snapshot.value?.toString().toLowerCase() ?? 'user';
        print('[UserService] role from DB = $roleValue'); // para depuração temporária
        return roleValue == 'admin';
      });

  /// Lista de IDs de crops atribuídas a este utilizador (ou [] se não existir).
  Future<List<String>> myCropIds() async {
    final snap = await _db.child('users/$_uid/crops').get();
    if (!snap.exists) return [];
    // O valor em "crops" deve ser um Array <String>
    return List<String>.from(snap.value as List<dynamic>);
  }
}
