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
            leading: const Icon(Icons.person_add),
            title: const Text('Assign crop to user'),
            onTap: () => _assignCropDialog(context, db),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_remove),
            title: const Text('Remove crop from user'),
            onTap: () => _deleteUserFromCropDialog(context, db),
          ),
        ],
      ),
    );
  }

  /// Diálogo que remove UMA crop da lista de crops de um user,
  /// em vez de apagar todo o nó do user.
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
            TextField(
              controller: uidCtrl,
              decoration: const InputDecoration(labelText: 'User UID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cropCtrl,
              decoration: const InputDecoration(labelText: 'Crop ID to remove'),
            ),
          ],
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
              final uid = uidCtrl.text.trim();
              final cropId = cropCtrl.text.trim();

              // Validação de campos vazios
              if (uid.isEmpty || cropId.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Por favor preencha ambos os campos.')),
                );
                return;
              }

              final ref = db.child('users/$uid/crops');
              final snap = await ref.get();

              if (!snap.exists) {
                // Se não existir lista de crops para este user, não há nada a remover
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Utilizador "$uid" não tem crops atribuídas.')),
                );
                return;
              }

              // Lista atual de crops
              final currentList = List<String>.from(snap.value as List);

              if (!currentList.contains(cropId)) {
                // Se o crop não estiver na lista, não faz sentido remover
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Crop "$cropId" não está atribuído ao utilizador "$uid".')),
                );
                return;
              }

              // Remove a cropId e atualiza no Firebase
              currentList.remove(cropId);
              await ref.set(currentList);

              // Fecha o diálogo
              Navigator.of(ctx).pop();

              // Mensagem de sucesso
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Crop "$cropId" removido do utilizador "$uid" com sucesso.')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Diálogo que adiciona UMA crop à lista de crops de um user
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
            TextField(
              controller: uidCtrl,
              decoration: const InputDecoration(labelText: 'User UID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cropCtrl,
              decoration: const InputDecoration(labelText: 'Crop ID to assign'),
            ),
          ],
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
              final uid = uidCtrl.text.trim();
              final cropId = cropCtrl.text.trim();

              // Validação de campos vazios
              if (uid.isEmpty || cropId.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Por favor preencha ambos os campos.')),
                );
                return;
              }

              final ref = db.child('users/$uid/crops');
              final snap = await ref.get();

              // Lista atual de crops (ou lista vazia se não existir ainda)
              final currentList = snap.exists
                  ? List<String>.from(snap.value as List)
                  : <String>[];

              if (currentList.contains(cropId)) {
                // Se já contém, mostra mensagem e não adiciona novamente
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Crop "$cropId" já está atribuído ao utilizador "$uid".')),
                );
                return;
              }

              // Adiciona à lista e grava no Firebase
              currentList.add(cropId);
              await ref.set(currentList);

              // Fecha o diálogo
              Navigator.of(ctx).pop();

              // Mensagem de sucesso
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Crop "$cropId" atribuído ao utilizador "$uid" com sucesso.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
