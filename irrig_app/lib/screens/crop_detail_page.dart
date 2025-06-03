import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../services/user_service.dart';



/// Esta “porta” verifica se o utilizador atual tem permissão para ver o detalhe:
/// - É admin → deixa entrar
/// - Caso contrário, verifica se a crop.id está na lista de crops atribuídas a ele.
/// Se não tiver permissão, mostra uma mensagem de acesso negado.
class CropDetailGate extends StatelessWidget {
  final Crop crop;
  const CropDetailGate({Key? key, required this.crop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userSvc = context.read<UserService>();

    return FutureBuilder<List<String>>(
      future: userSvc.myCropIds(),
      builder: (context, futureSnap) {
        if (futureSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allowedList = futureSnap.data ?? <String>[];
        final bool isAssigned = allowedList.contains(crop.id);

        return StreamBuilder<bool>(
          stream: userSvc.isAdminStream,
          builder: (context, adminSnap) {
            final bool isAdmin = adminSnap.data ?? false;

            if (isAdmin || isAssigned) {
              // Se for admin OU tiver a crop atribuída → mostra os detalhes
              return CropDetailPage(crop: crop);
            } else {
              // Caso contrário, acesso negado
              return Scaffold(
                appBar: AppBar(title: const Text('Crop details')),
                body: const Center(
                  child: Text(
                    'Access denied: you are not assigned to this crop.',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

/// Este widget mostra os detalhes completos da Crop.
/// Aqui deves colocar gráficos, histórico, formulários de edição, etc.
/// No exemplo abaixo colocámos apenas um layout de exemplo.
class CropDetailPage extends StatelessWidget {
  final Crop crop;
  const CropDetailPage({Key? key, required this.crop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Podes ler mais dados da crop através do DataService, se houver um endpoint para isso.
    final ds = context.read<DataService>();
    final userSvc = context.read<UserService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Crop: ${crop.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exibe informações básicas
            Text('ID: ${crop.id}', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Type: ${crop.type}', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),

            // Exemplo de espaço para gráficos/histórico
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart, size: 64, color: Colors.blue),
                    const SizedBox(height: 12),
                    Text(
                      'Graphs & historical data go here',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            /*// Podes adicionar botões de “Editar”, “Ver métricas em tempo real”, etc.
            // Caso o utilizador seja admin ou tenha permissão, permite edição:
            StreamBuilder<bool>(
              stream: userSvc.isAdminStream,
              builder: (context, adminSnap) {
                final bool isAdmin = adminSnap.data ?? false;
                if (isAdmin) {
                  return ElevatedButton.icon(
                    onPressed: () {
                      // Exemplo de ação extra só para admin
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Crop'),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),*/
          ],
        ),
      ),
    );
  }
}
