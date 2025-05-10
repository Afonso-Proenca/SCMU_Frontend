import 'package:flutter/material.dart';

class WaterTankInfoPage extends StatelessWidget {
  const WaterTankInfoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water Tank Info')),
      body: const Center(
        child: Text('Water Tank Info page'),
      ),
    );
  }
}