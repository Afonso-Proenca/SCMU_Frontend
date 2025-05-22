import 'package:flutter/material.dart';
import '../firebase/sensorData.dart';

class CropsPage extends StatelessWidget {
  const CropsPage({Key? key}) : super(key: key);

  final String sensorPath = 'sensors'; //location in db

  @override
  Widget build(BuildContext context) {
    final sensorService = SensorDataService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crops'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: sensorService.streamSensorData(sensorPath),
        builder: (context, snapshot) {
          print('ConnectionState: ${snapshot.connectionState}');
          print('HasData: ${snapshot.hasData}');
          print('HasError: ${snapshot.hasError}');
          print('Error: ${snapshot.error}');
          if (snapshot.hasError) return Text('Error: ${snapshot.error}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            print("here");
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No sensor data available'));
          }

          final data = snapshot.data!;
          print(data);
          final humidity = data['humidity']?.toString() ?? 'N/A';
          final temperature = data['temp']?.toString() ?? 'N/A';
          final timestamp = data['timestamp'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensor Data',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text('Temperature: $temperature °C', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text('Humidity: $humidity %', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                if (timestamp != null)
                  Text('Last updated: ${DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}
