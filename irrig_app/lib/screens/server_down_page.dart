import 'package:flutter/material.dart';

class ServerDownPage extends StatelessWidget {
  const ServerDownPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud_off, size: 96, color: Colors.blueGrey),
              SizedBox(height: 24),
              Text('Server is currently down', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Please try again later.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}