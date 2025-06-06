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
                // botão “delete” visível só para admins — mantém-se igual
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
      // FAB visível apenas para administradores — mantém-se igual
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

  // ---------- diálogo de criação/edição ----------
  void _showAddDialog(BuildContext ctx, DataService ds) {
    final nameCtrl = TextEditingController();
    final typeOptions = [
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

    // controladores para os limites
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
                          .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedType = val!),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    const Divider(),
                    // ---- campos SEMPRE visíveis ----
                    TextField(
                      controller: humidityMinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                      const InputDecoration(labelText: 'Humidity Min'),
                    ),
                    TextField(
                      controller: humidityMaxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                      const InputDecoration(labelText: 'Humidity Max'),
                    ),
                    TextField(
                      controller: lightMinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Light Min'),
                    ),
                    TextField(
                      controller: lightMaxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Light Max'),
                    ),
                    TextField(
                      controller: tempMinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Temp Min'),
                    ),
                    TextField(
                      controller: tempMaxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Temp Max'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Construímos SEMPRE o mapa de settings;
                    // zeros indicam que queremos usar o default do backend
                    final settings = {
                      'humidity': {
                        'min': double.tryParse(humidityMinCtrl.text) ?? 0,
                        'max': double.tryParse(humidityMaxCtrl.text) ?? 0,
                      },
                      'light': {
                        'min': double.tryParse(lightMinCtrl.text) ?? 0,
                        'max': double.tryParse(lightMaxCtrl.text) ?? 0,
                      },
                      'temperature': {
                        'min': double.tryParse(tempMinCtrl.text) ?? 0,
                        'max': double.tryParse(tempMaxCtrl.text) ?? 0,
                      },
                    };

                    ds.addCrop(
                      nameCtrl.text,
                      selectedType,
                      settings,
                    );
                    Navigator.of(ctx).pop();
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
