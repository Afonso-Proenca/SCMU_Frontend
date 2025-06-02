import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    final db = ds.db;        

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            leading: const Icon(Icons.person_remove),
            title: const Text('Delete user'),
            onTap: () => _deleteUserDialog(context, db),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Assign crop to user'),
            onTap: () => _assignCropDialog(context, db),
          ),
        ],
      ),
    );
  }

  void _deleteUserDialog(BuildContext ctx, DatabaseReference db) {
    final uidCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete user'),
        content: TextField(
          controller: uidCtrl,
          decoration: const InputDecoration(labelText: 'User UID'),
        ),
        actions: [
          TextButton(onPressed: Navigator.of(ctx).pop, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await db.child('users/${uidCtrl.text}').remove();
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _assignCropDialog(BuildContext ctx, DatabaseReference db) {
    final uidCtrl = TextEditingController();
    final cropCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Assign crop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: uidCtrl, decoration: const InputDecoration(labelText: 'User UID')),
            TextField(controller: cropCtrl, decoration: const InputDecoration(labelText: 'Crop ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: Navigator.of(ctx).pop, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ref = db.child('users/${uidCtrl.text}/crops');
              final snap = await ref.get();
              final list = snap.exists ? List<String>.from(snap.value as List) : <String>[];
              if (!list.contains(cropCtrl.text)) list.add(cropCtrl.text);
              await ref.set(list);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
