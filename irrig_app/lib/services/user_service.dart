import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserService {
  final _db  = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Stream que devolve true/false conforme 'users/$_uid/role' seja igual a 'admin'.
  Stream<bool> get isAdminStream async* {
    final userChanges = FirebaseAuth.instance.userChanges();
    await for (final user in userChanges) {
      if (user == null) {
        yield false;
        continue;
      }

      final idTokenResult = await user.getIdTokenResult(true);
      final isAdmin = idTokenResult.claims?['cropAdmin'] == true;
      print('[UserService] UID=${user.uid} | admin = $isAdmin');
      yield isAdmin;
    }
  }




  /// Lista de IDs de crops atribuídas a este utilizador (ou [] se não existir).
  Future<List<String>> myCropIds() async {
    final snap = await _db.child('users/$_uid/crops').get();
    if (!snap.exists) return [];
    // O valor em "crops" deve ser um Array <String>
    return List<String>.from(snap.value as List<dynamic>);
  }
}
