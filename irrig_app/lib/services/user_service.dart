import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  final _db  = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Stream que devolve true/false conforme o utilizador tenha
  /// a *custom claim* `cropAdmin = true`.
  Stream<bool> get isAdminStream async* {
    final userChanges = FirebaseAuth.instance.userChanges();
    await for (final user in userChanges) {
      if (user == null) {
        yield false;
        continue;
      }
      final idTokenResult = await user.getIdTokenResult(true);
      yield idTokenResult.claims?['cropAdmin'] == true;
    }
  }

  /// Lista de **IDs** das crops atribuídas a este utilizador.
  /// Aceita tanto o formato antigo `[{'id': 'crop1', 'name': ...}]`
  /// como o formato novo `['crop1', 'crop2']`.
  Future<List<String>> myCropIds() async {
    final snap = await _db.child('users/$_uid/crops').get();
    if (!snap.exists) return [];

    final list = snap.value as List<dynamic>;
    return list
        .map((e) {
      if (e is String) return e;
      if (e is Map && e.containsKey('id')) return e['id'] as String;
      return null;
    })
        .whereType<String>()
        .toList();
  }

  // ---- REST/Cloud Function utilitário já existente ----
  Future<List<Map<String, dynamic>>> fetchFilteredUsers() async {
    const url =
        'https://europe-southwest1-scmu-6f1b8.cloudfunctions.net/list_filtered_users';

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final idToken = await user.getIdToken();

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch users: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final users = data['users'] as List;
    return users.map((u) => Map<String, dynamic>.from(u)).toList();
  }
}
