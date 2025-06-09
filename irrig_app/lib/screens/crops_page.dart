import 'package:flutter/material.dart';
import 'package:irrig_app/services/user_service.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../screens/crop_detail_page.dart';

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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CropDetailGate(crop: c)),
                ),
                trailing: StreamBuilder<bool>(
                  stream: userSvc.isAdminStream,
                  builder: (_, s) {
                    final isAdmin = s.data ?? false;
                    return isAdmin
                        ? IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => ds.deleteCrop(c.id),
                    )
                        : const SizedBox.shrink();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: userSvc.isAdminStream,
        builder: (_, s) {
          final isAdmin = s.data ?? false;
          return isAdmin
              ? FloatingActionButton(
            onPressed: () => _showAddDialog(context, ds),
            child: const Icon(Icons.add),
          )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  // ---------- diálogo de criação ----------
  void _showAddDialog(BuildContext ctx, DataService ds) {
    final nameCtrl = TextEditingController();
    const typeOptions = [
      'custom',
      'carrot',
      'corn',
      'cucumber',
      'lettuce',
      'potato',
      'rice',
      'soybean',
      'strawberry',
      'tomato',
      'wheat'
    ];
    String selectedType = 'custom';

    final humidityMinCtrl = TextEditingController();
    final humidityMaxCtrl = TextEditingController();
    final lightMinCtrl = TextEditingController();
    final lightMaxCtrl = TextEditingController();
    final tempMinCtrl = TextEditingController();
    final tempMaxCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Crop'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: typeOptions
                          .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedType = val!),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    if (selectedType == 'custom') ...[
                      const Divider(),
                      TextField(
                        controller: humidityMinCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Humidity Min'),
                      ),
                      TextField(
                        controller: humidityMaxCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Humidity Max'),
                      ),
                      TextField(
                        controller: lightMinCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Light Min'),
                      ),
                      TextField(
                        controller: lightMaxCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Light Max'),
                      ),
                      TextField(
                        controller: tempMinCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Temp Min'),
                      ),
                      TextField(
                        controller: tempMaxCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Temp Max'),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final settings = selectedType == 'custom'
                        ? {
                      'humidity': {
                        'min':
                        double.tryParse(humidityMinCtrl.text) ?? 0,
                        'max':
                        double.tryParse(humidityMaxCtrl.text) ?? 0,
                      },
                      'light': {
                        'min': double.tryParse(lightMinCtrl.text) ?? 0,
                        'max': double.tryParse(lightMaxCtrl.text) ?? 0,
                      },
                      'temperature': {
                        'min': double.tryParse(tempMinCtrl.text) ?? 0,
                        'max': double.tryParse(tempMaxCtrl.text) ?? 0,
                      },
                    }
                        : <String, Map<String, double>>{};

                    try {
                      await ds.addCrop(
                        nameCtrl.text,
                        selectedType,
                        settings,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop(); // fecha diálogo
                    } on ArgumentError catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    } catch (_) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('Failed to create crop')),
                      );
                    }
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
