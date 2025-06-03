import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  final _db  = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Stream que devolve true/false conforme 'user' seja igual a 'cropAdmin'.
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


  Future<List<Map<String, dynamic>>> fetchFilteredUsers() async {
    const url = 'https://europe-southwest1-scmu-6f1b8.cloudfunctions.net/list_filtered_users';

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final idToken = await user.getIdToken();

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final users = data['users'] as List;
      return users.map((u) => Map<String, dynamic>.from(u)).toList();
    } else {
      throw Exception('Failed to fetch users: ${response.statusCode} - ${response.body}');
    }
  }

}
