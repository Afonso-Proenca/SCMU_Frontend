import 'package:flutter/material.dart';
import 'crops_page.dart';
import 'irrigation_settings_page.dart';
import 'water_tank_info_page.dart';
import 'add_crop_page.dart';

class BackOfficePage extends StatelessWidget {
  const BackOfficePage({Key? key}) : super(key: key);

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Page (Admin)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          children: [
            _MenuTile(icon: Icons.grass, label: 'Crops', onTap: () => _navigate(context, const CropsPage())),
            _MenuTile(
              icon: Icons.settings,
              label: 'Irrigation Settings',
              onTap: () => _navigate(context, const IrrigationSettingsPage()),
            ),
            _MenuTile(
              icon: Icons.water_drop,
              label: 'Water tank info',
              onTap: () => _navigate(context, const WaterTankInfoPage()),
            ),
            _MenuTile(icon: Icons.add, label: 'Add Crop', onTap: () => _navigate(context, const AddCropPage())),
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
  const _MenuTile({Key? key, required this.icon, required this.label, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.green.shade600),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}