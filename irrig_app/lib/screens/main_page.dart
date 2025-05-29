import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/data_service.dart';
import 'crops_page.dart';
import 'irrigation_settings_page.dart';
import 'water_tank_info_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Apenas para forçar o Provider a instanciar o serviço,
    // embora não o usemos diretamente aqui.
    context.read<DataService>();
    // Também podemos aceder ao AuthService se precisarmos.
    // context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          children: [
            _MenuTile(
              icon: Icons.grass,
              label: 'Crops',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CropsPage()),
              ),
            ),
            _MenuTile(
              icon: Icons.settings,
              label: 'Irrigation Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IrrigationSettingsPage()),
              ),
            ),
            _MenuTile(
              icon: Icons.water_drop,
              label: 'Water tank info',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WaterTankInfoPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue.shade600),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
