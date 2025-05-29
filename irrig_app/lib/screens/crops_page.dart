import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';

class CropsPage extends StatelessWidget {
  const CropsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crops')),
      body: StreamBuilder<Iterable<Crop>>(
        stream: ds.cropsStream(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final crops = snap.data!.toList();
          if (crops.isEmpty) return const Center(child: Text('No crops yet'));
          return ListView.builder(
            itemCount: crops.length,
            itemBuilder: (_, i) {
              final c = crops[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(c.type),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => ds.deleteCrop(c.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, ds),
      ),
    );
  }

  void _showAddDialog(BuildContext ctx, DataService ds) {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Add Crop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type')),
          ],
        ),
        actions: [
          TextButton(onPressed: Navigator.of(ctx).pop, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ds.addCrop(nameCtrl.text, typeCtrl.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
