import 'package:flutter/material.dart';

class AddCropPage extends StatelessWidget {
  const AddCropPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Crop')),
      body: const Center(
        child: Text('Add Crop page'),
      ),
    );
  }
}