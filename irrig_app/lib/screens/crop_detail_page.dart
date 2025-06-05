import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';

class CropDetailPage extends StatelessWidget {
  final Crop crop;
  const CropDetailPage({Key? key, required this.crop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    final userSvc = context.read<UserService>();

    return Scaffold(
      appBar: AppBar(title: Text('Crop "${crop.name}"')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID : ${crop.id}',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Type : ${crop.type}',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),

            // -------- Lista de utilizadores atribuídos (apenas admins) --------
            StreamBuilder<bool>(
              stream: userSvc.isAdminStream,
              builder: (_, adminSnap) {
                final isAdmin = adminSnap.data ?? false;
                if (!isAdmin) return const SizedBox.shrink();

                return StreamBuilder<Iterable<UserInfoDB>>(
                  stream: ds.usersStream(),
                  builder: (_, usersSnap) {
                    if (!usersSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final assigned = usersSnap.data!
                        .where((u) => u.crops.contains(crop.id))
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Text('Assigned users:',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (assigned.isEmpty)
                          const Text('Nenhum utilizador atribuído.')
                        else
                          ...assigned.map((u) => ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(u.name ?? u.uid),
                                subtitle: Text(u.uid),
                              )),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bar_chart, size: 64, color: Colors.blue),
                    SizedBox(height: 12),
                    Text('Graphs & historical data go here'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
