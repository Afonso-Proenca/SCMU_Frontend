import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../services/user_service.dart';
import 'crop_detail_page.dart';      // pagina de detalhe verdadeira

class CropsPage extends StatelessWidget {
  const CropsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    final userSvc = context.read<UserService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crops')),
      body: StreamBuilder<Iterable<Crop>>(
        stream: ds.cropsStream(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final crops = snap.data!.toList();
          if (crops.isEmpty) {
            return const Center(child: Text('No crops yet'));
          }

          return ListView.builder(
            itemCount: crops.length,
            itemBuilder: (_, i) {
              final c = crops[i];

              return ListTile(
                title: Text(c.name),
                subtitle: Text(c.type),

                // ---------- clique ----------
                onTap: () async {
                  final isAdmin =
                      await userSvc.isAdminStream.first;      // devolve bool
                  final myCrops = await userSvc.myCropIds();  // lista atribuída

                  final allowed = isAdmin || myCrops.contains(c.id);

                  if (allowed) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CropDetailPage(crop: c)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Access denied: crop not assigned.')),
                    );
                  }
                },

                // ---------- botão delete (só para admins) ----------
                trailing: StreamBuilder<bool>(
                  stream: userSvc.isAdminStream,
                  builder: (_, s) => (s.data ?? false)
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => ds.deleteCrop(c.id),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),

      // ---------- FAB para adicionar crop (só admins) ----------
      floatingActionButton: StreamBuilder<bool>(
        stream: userSvc.isAdminStream,
        builder: (_, s) => (s.data ?? false)
            ? FloatingActionButton(
                child: const Icon(Icons.add),
                onPressed: () => _showAddDialog(context, ds),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /* diálogo Add Crop (mantém-se igual, já suporta settings) */
  void _showAddDialog(BuildContext ctx, DataService ds) {
    final nameCtrl = TextEditingController();
    final typeOptions = [
      'custom', 'carrot', 'corn', 'cucumber', 'lettuce',
      'potato', 'rice', 'soybean', 'strawberry', 'tomato', 'wheat'
    ];
    String selectedType = 'custom';

    final humMin = TextEditingController();
    final humMax = TextEditingController();
    final lightMin = TextEditingController();
    final lightMax = TextEditingController();
    final tempMin = TextEditingController();
    final tempMax = TextEditingController();

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Crop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: typeOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                if (selectedType == 'custom') ...[
                  const Divider(),
                  TextField(controller: humMin,   decoration: const InputDecoration(labelText: 'Humidity Min')),
                  TextField(controller: humMax,   decoration: const InputDecoration(labelText: 'Humidity Max')),
                  TextField(controller: lightMin, decoration: const InputDecoration(labelText: 'Light Min')),
                  TextField(controller: lightMax, decoration: const InputDecoration(labelText: 'Light Max')),
                  TextField(controller: tempMin,  decoration: const InputDecoration(labelText: 'Temp Min')),
                  TextField(controller: tempMax,  decoration: const InputDecoration(labelText: 'Temp Max')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: Navigator.of(ctx).pop, child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final settings = selectedType == 'custom'
                    ? {
                        'humidity': {
                          'min': double.tryParse(humMin.text) ?? 0,
                          'max': double.tryParse(humMax.text) ?? 0,
                        },
                        'light': {
                          'min': double.tryParse(lightMin.text) ?? 0,
                          'max': double.tryParse(lightMax.text) ?? 0,
                        },
                        'temperature': {
                          'min': double.tryParse(tempMin.text) ?? 0,
                          'max': double.tryParse(tempMax.text) ?? 0,
                        },
                      }
                    : <String, Map<String, double>>{};

                ds.addCrop(nameCtrl.text.trim(), selectedType, settings);
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
