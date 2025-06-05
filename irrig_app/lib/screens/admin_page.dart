import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    final db = ds.db;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: StreamBuilder<Iterable<UserInfoDB>>(
        stream: ds.usersStream(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snap.data!.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: users.length + 2,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (i == 0) {
                return ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Assign crop to user'),
                  onTap: () => _assignCropDialog(_, db),
                );
              }
              if (i == 1) {
                return ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('Remove crop from user'),
                  onTap: () => _deleteUserFromCropDialog(_, db),
                );
              }

              final u = users[i - 2];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(u.name ?? u.uid),
                subtitle: Text('crops: ${u.crops.length}'),
              );
            },
          );
        },
      ),
    );
  }

  // -------- diálogos assign / delete (com snackbars) --------
  void _assignCropDialog(BuildContext ctx, DatabaseReference db) {
    final uidCtrl = TextEditingController();
    final cropCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Assign crop to user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: uidCtrl, decoration: const InputDecoration(labelText: 'User UID')),
            const SizedBox(height: 12),
            TextField(controller: cropCtrl, decoration: const InputDecoration(labelText: 'Crop ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: Navigator.of(ctx).pop, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = uidCtrl.text.trim();
              final cropId = cropCtrl.text.trim();
              if (uid.isEmpty || cropId.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Preencha ambos os campos.')));
                return;
              }
              final ref = db.child('users/$uid/crops');
              final snap = await ref.get();
              final list = snap.exists ? List<String>.from(snap.value as List) : <String>[];
              if (list.contains(cropId)) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Crop "$cropId" já atribuída.')));
                return;
              }
              list.add(cropId);
              await ref.set(list);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Crop "$cropId" atribuída a "$uid".')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteUserFromCropDialog(BuildContext ctx, DatabaseReference db) {
    final uidCtrl = TextEditingController();
    final cropCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove crop from user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: uidCtrl, decoration: const InputDecoration(labelText: 'User UID')),
            const SizedBox(height: 12),
            TextField(controller: cropCtrl, decoration: const InputDecoration(labelText: 'Crop ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: Navigator.of(ctx).pop, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = uidCtrl.text.trim();
              final cropId = cropCtrl.text.trim();
              if (uid.isEmpty || cropId.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Preencha ambos os campos.')));
                return;
              }
              final ref = db.child('users/$uid/crops');
              final snap = await ref.get();
              if (!snap.exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Utilizador "$uid" não tem crops.')));
                return;
              }
              final list = List<String>.from(snap.value as List);
              if (!list.contains(cropId)) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Crop "$cropId" não atribuída.')));
                return;
              }
              list.remove(cropId);
              await ref.set(list);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Crop "$cropId" removida de "$uid".')));
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
