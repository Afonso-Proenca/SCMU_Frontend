import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = context.read<UserService>().fetchFilteredUsers();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    final db = ds.db;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (userSnapshot.hasError) {
            return Text('Error loading users: ${userSnapshot.error}');
          }

          final users = userSnapshot.data ?? [];

          return StreamBuilder<Iterable<Crop>>(
            stream: ds.cropsStream(),
            builder: (context, cropSnapshot) {
              if (cropSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (cropSnapshot.hasError) {
                return Text('Error loading crops: ${cropSnapshot.error}');
              }

              final crops = cropSnapshot.data?.toList() ?? [];

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Assign crop to user'),
                    onTap: () => _assignCropDialog(context, db, users, crops),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person_remove),
                    title: const Text('Remove crop from user'),
                    onTap: () =>
                        _deleteUserFromCropDialog(context, db, users, crops),
                  ),
                  const Divider(),
                  const Text('Users',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...users.map((user) {
                    print(user);

                    final email = user['email'] as String? ?? 'No email';
                    final uid = user['uid'] as String? ?? '';
                    String cropNames = '';
                    if (user['crops'] is List) {
                      final list = user['crops'] as List<dynamic>;

                      final names = list
                          .map((e) {
                            final m = Map<String, dynamic>.from(e as Map);
                            return m['name'] as String? ?? '';
                          })
                          .where((n) => n.isNotEmpty)
                          .toList();
                      cropNames = names.join(', ');
                    }

                    return ListTile(
                      title: Text(email),
                      subtitle: Text(uid),
                      trailing: Text(cropNames),
                    );
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Diálogo que remove UMA crop da lista de crops de um user,
  /// em vez de apagar todo o nó do user.
  void _deleteUserFromCropDialog(BuildContext ctx, DatabaseReference db,
      List<Map<String, dynamic>> users, List<Crop> crops) {
    /*final uidCtrl = TextEditingController();
    final cropCtrl = TextEditingController();*/
    String? selectedUid;
    String? selectedCropId;
    showDialog(
      context: ctx,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            final validUids =
                users.map((u) => u['uid']).whereType<String>().toList();
            final validCropIds =
                crops.map((c) => c.id).whereType<String>().toList();

            if (selectedUid != null && !validUids.contains(selectedUid)) {
              selectedUid = null;
            }
            if (selectedCropId != null &&
                !validCropIds.contains(selectedCropId)) {
              selectedCropId = null;
            }
            return AlertDialog(
              title: const Text('Remove crop from user'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /*TextField(
              controller: uidCtrl,
              decoration: const InputDecoration(labelText: 'User UID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cropCtrl,
              decoration: const InputDecoration(labelText: 'Crop ID to remove'),
            ),*/
                    DropdownButtonFormField<String>(
                      hint: const Text("Select User"),
                      value: selectedUid,
                      items: validUids.map<DropdownMenuItem<String>>((uid) {
                        final userMap =
                            users.firstWhere((u) => u['uid'] == uid);
                        final displayText =
                            (userMap['email'] as String? ?? 'Unknown');
                        return DropdownMenuItem<String>(
                          value: uid,
                          child: Text(displayText),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedUid = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      hint: const Text("Select Crop"),
                      value: selectedCropId,
                      items:
                          validCropIds.map<DropdownMenuItem<String>>((cropId) {
                        final cropName =
                            crops.firstWhere((c) => c.id == cropId).name;
                        return DropdownMenuItem<String>(
                          value: cropId,
                          child: Text(cropName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedCropId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final uid = selectedUid;
                    final cropId = selectedCropId;

                    // Validação de campos vazios
                    if (uid!.isEmpty || cropId!.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Por favor selecione ambos os campos.')),
                      );
                      return;
                    }

                    final ref = db.child('users/$uid/crops');
                    final snap = await ref.get();

                    if (!snap.exists) {
                      // Se não existir lista de crops para este user, não há nada a remover
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Utilizador "$uid" não tem crops atribuídas.')),
                      );
                      return;
                    }

                    // Lista atual de crops para map id nome de crop
                    final list = snap.value as List<dynamic>;
                    final currentList = list.map((e) {
                      final m = Map<String, dynamic>.from(e as Map);
                      return {
                        'id': m['id'] as String,
                        'name': m['name'] as String,
                      };
                    }).toList();

                    final indexToRemove =
                        currentList.indexWhere((m) => m['id'] == cropId);
                    if (indexToRemove < 0) {
                      // Se o crop não estiver na lista, não faz sentido remover
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Crop "$cropId" não está atribuído ao utilizador "$uid".')),
                      );
                      return;
                    }

                    // Remove a cropId e atualiza no Firebase
                    currentList.removeAt(indexToRemove);
                    await ref.set(currentList);

                    // Fecha o diálogo
                    Navigator.of(ctx).pop();

                    // Mensagem de sucesso
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Crop "$cropId" removido do utilizador "$uid" com sucesso.')),
                    );
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Diálogo que adiciona UMA crop à lista de crops de um user
  void _assignCropDialog(BuildContext ctx, DatabaseReference db,
      List<Map<String, dynamic>> users, List<Crop> crops) {
    /*final uidCtrl = TextEditingController();
    final cropCtrl = TextEditingController();*/
    String? selectedUid;
    String? selectedCropId;

    showDialog(
      context: ctx,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            final validUids =
                users.map((u) => u['uid']).whereType<String>().toList();
            final validCropIds =
                crops.map((c) => c.id).whereType<String>().toList();
            print(">>> validUids: $validUids");
            print(">>> validCropIds: $validCropIds");
            print('Full users list: $users');
            print('Full crops list: $crops');

            if (selectedUid != null && !validUids.contains(selectedUid)) {
              selectedUid = null;
            }
            if (selectedCropId != null &&
                !validCropIds.contains(selectedCropId)) {
              selectedCropId = null;
            }
            return AlertDialog(
              title: const Text('Assign crop to user'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /*TextField(
              controller: uidCtrl,
              decoration: const InputDecoration(labelText: 'User UID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cropCtrl,
              decoration: const InputDecoration(labelText: 'Crop ID to assign'),
            ),*/
                    DropdownButtonFormField<String>(
                      hint: const Text("Select User"),
                      value: selectedUid,
                      isExpanded: true,
                      items: validUids.map<DropdownMenuItem<String>>((uid) {
                        final userMap =
                            users.firstWhere((u) => u['uid'] == uid);
                        final displayText =
                            (userMap['email'] as String? ?? 'Unknown');
                        return DropdownMenuItem<String>(
                          value: uid,
                          child: Text(displayText),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedUid = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      hint: const Text("Select Crop"),
                      value: selectedCropId,
                      items:
                          validCropIds.map<DropdownMenuItem<String>>((cropId) {
                        final cropName =
                            crops.firstWhere((c) => c.id == cropId).name;
                        return DropdownMenuItem<String>(
                          value: cropId,
                          child: Text(cropName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedCropId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final uid = selectedUid;
                    final cropId = selectedCropId;

                    // Validação de campos vazios
                    if (uid!.isEmpty || cropId!.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Por favor selecione ambos os campos.')),
                      );
                      return;
                    }

                    final ref = db.child('users/$uid/crops');
                    final snap = await ref.get();

                    // List objetos crop
                    List<Map<String, String>> currentList;
                    if (snap.exists) {
                      final list = snap.value as List<dynamic>;
                      currentList = list.map((e) {
                        final m = Map<String, dynamic>.from(e as Map);
                        return {
                          'id': m['id'] as String,
                          'name': m['name'] as String,
                        };
                      }).toList();
                    } else {
                      currentList = <Map<String, String>>[];
                    }

                    //vê se ja está nas lista
                    final alreadyHas =
                        currentList.any((m) => m['id'] == cropId);
                    if (alreadyHas) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Crop "$cropId" já está atribuído ao utilizador "$uid".'),
                        ),
                      );
                      return;
                    }
                    // se n adiciona entry id and name
                    final cropName =
                        crops.firstWhere((c) => c.id == cropId).name;
                    currentList.add({'id': cropId, 'name': cropName});

                    await ref.set(currentList);

                    Navigator.of(ctx).pop();

                    // Mensagem de sucesso
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Crop "$cropId" atribuído ao utilizador "$uid" com sucesso.')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
