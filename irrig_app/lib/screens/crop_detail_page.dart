import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';
import 'package:firebase_database/firebase_database.dart';

class CropDetailGate extends StatefulWidget {
  final Crop crop;

  const CropDetailGate({required this.crop, Key? key}) : super(key: key);
  @override
  _CropDetailGateState createState() => _CropDetailGateState();
}

class _CropDetailGateState extends State<CropDetailGate> {
  bool showNoDataMessage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          showNoDataMessage = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    final us = context.read<UserService>();

    return FutureBuilder<List<String>>(
      future: us.myCropIds(),
      builder: (context, futureSnap) {
        if (futureSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final allowedList = futureSnap.data ?? <String>[];

        return StreamBuilder<bool>(
          stream: us.isAdminStream,
          initialData: false,
          builder: (context, adminSnap) {
            final bool isAdmin = adminSnap.data ?? false;
            final bool isAssigned = allowedList.contains(widget.crop.id);
            print(
                'CropDetailGate: isAdmin=$isAdmin, isAssigned=$isAssigned, cropId=${widget.crop.id}, allowedList=$allowedList');

            if (!isAssigned && !isAdmin){
              return Scaffold(
                appBar: AppBar(title: Text('Crop • ${widget.crop.name}')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Access Denied',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You are not assigned to view this crop.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // --------------------- página de detalhes ------------------------

                   return Scaffold(
              appBar: AppBar(title: Text('Crop • ${widget.crop.name}')),
              body: StreamBuilder<List<SensorData>>(
                stream: ds.lastHourSensorDataStream(widget.crop.id,widget.crop.type),
                builder: (_, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) {
                    if (snap.connectionState == ConnectionState.waiting && !showNoDataMessage) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      return const Center(child: Text('No sensor data yet'));
                    }
                  }
                  final data = snap.data!;

                  final tempSpots = <FlSpot>[];
                  final humSpots = <FlSpot>[];
                  for (var i = 0; i < data.length; i++) {
                    tempSpots.add(FlSpot(i.toDouble(), data[i].temperature));
                    humSpots.add(FlSpot(i.toDouble(), data[i].moisture));
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${widget.crop.type}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    interval: tempSpots.length ~/ 4 > 0
                                        ? (tempSpots.length / 4)
                                        : 1,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.round();
                                      if (idx < 0 || idx >= data.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final ts = data[idx].timestamp;
                                      return SideTitleWidget(
                                        meta: meta,
                                        child: Text(
                                          DateFormat.Hm().format(ts),
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 5,
                                  ),
                                ),
                              ),
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: tempSpots,
                                  isCurved: true,
                                  barWidth: 2,
                                  color: Colors.redAccent,
                                  dotData: FlDotData(show: false),
                                ),
                                LineChartBarData(
                                  spots: humSpots,
                                  isCurved: true,
                                  barWidth: 2,
                                   color: Colors.blueAccent,
                                  dotData: FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                                               _LegendDot(

                                label: 'Temperature (°C)',

                                color: Colors.redAccent),

                            _LegendDot(

                                label: 'Humidity (%)',

                                color: Colors.blueAccent),

                          ],

                        ),

                      ],

                    ),

                  );

                },

              ),

            );

          },

        );

      },

    );

  }

}



class _LegendDot extends StatelessWidget {

  final String label;

  final Color color;



  const _LegendDot({required this.label, required this.color, Key? key})

      : super(key: key);



  @override

  Widget build(BuildContext context) => Row(

        children: [

          Container(

            width: 10,

            height: 10,

            decoration:

                BoxDecoration(shape: BoxShape.circle, color: color),

          ),

          const SizedBox(width: 4),

          Text(label, style: const TextStyle(fontSize: 12)),

        ],

      );

}

