import 'package:flutter/material.dart';

class IrrigationSettingsPage extends StatelessWidget {
  const IrrigationSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Irrigation Settings')),
      body: const Center(
        child: Text('Irrigation Settings page'),
      ),
    );
  }
}