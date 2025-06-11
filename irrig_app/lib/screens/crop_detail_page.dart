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
  }

  @override
  void dispose() {
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

            if (!isAssigned && !isAdmin) {
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
                stream: ds.lastHourSensorDataStream(
                    widget.crop.id, widget.crop.type),
                builder: (_, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !showNoDataMessage) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return const Center(child: Text('No sensor data yet'));
                  }

                  final data = snap.data!;
                  final temp = <FlSpot>[];
                  final hum = <FlSpot>[];
                  final lux = <FlSpot>[];

                  for (var i = 0; i < data.length; i++) {
                    temp.add(FlSpot(i.toDouble(), data[i].temperature));
                    hum.add(FlSpot(i.toDouble(), data[i].moisture));
                    lux.add(FlSpot(i.toDouble(), data[i].light));
                  }

                  // ——— escala dinâmica ———
                  final maxVal = [
                    ...data.map((e) => e.temperature),
                    ...data.map((e) => e.moisture),
                    ...data.map((e) => e.light)
                  ].reduce((a, b) => a > b ? a : b);
                  double maxY = (maxVal * 1.1).clamp(10, double.infinity);
                  final intervalY = (maxY / 5).roundToDouble();

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${widget.crop.type}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        // ——— gráfico + legenda ———
                        Expanded(
                          child: Stack(
                            children: [
                              // gráfico
                              LineChart(
                                LineChartData(
                                  minY: 0,
                                  maxY: maxY,
                                  titlesData: FlTitlesData(
                                    topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        interval: (data.length / 4)
                                            .ceilToDouble()
                                            .clamp(1, double.infinity),
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.round();
                                          if (idx < 0 || idx >= data.length) {
                                            return const SizedBox.shrink();
                                          }
                                          return SideTitleWidget(
                                            meta: meta,
                                            child: Text(
                                              DateFormat.Hm()
                                                  .format(data[idx].timestamp),
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: intervalY,
                                        reservedSize: 40,
                                        getTitlesWidget: (v, _) => Text(
                                          v.toInt().toString(),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                      drawVerticalLine: true,
                                      horizontalInterval: intervalY),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    _bar(temp, Colors.redAccent),
                                    _bar(hum, Colors.blueAccent),
                                    _bar(lux, Colors.amber),
                                  ],
                                ),
                              ),
                              // legenda fixa
                              Positioned(
                                top: 8,
                                left: 5,
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: Card(
                                    elevation: 2,
                                    color: Theme.of(context)
                                        .cardColor
                                        .withOpacity(0.9),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          _LegendDot(
                                              label: 'Temperature (°C)',
                                              color: Colors.redAccent),
                                          SizedBox(height: 4),
                                          _LegendDot(
                                              label: 'Humidity (%)',
                                              color: Colors.blueAccent),
                                          SizedBox(height: 4),
                                          _LegendDot(
                                              label: 'Light',
                                              color: Colors.amber),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  //  helpers -----------------------------------------------------------------
  LineChartBarData _bar(List<FlSpot> spots, Color c) => LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 2,
        color: c,
        dotData: FlDotData(show: false),
      );

  Scaffold _deny() => Scaffold(
        appBar: AppBar(title: Text('Crop • ${widget.crop.name}')),
        body: const Center(child: Text('Access denied')),
      );
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
