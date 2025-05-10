import 'package:flutter/material.dart';

class CropsPage extends StatelessWidget {
  const CropsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crops')),
      body: const Center(
        child: Text('Crops page'),
      ),
    );
  }
}