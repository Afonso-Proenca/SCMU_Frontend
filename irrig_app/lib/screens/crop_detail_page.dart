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
  // estado das permissões
  List<String>? _allowedList;
  bool _isAdmin = false;
  StreamSubscription<bool>? _adminSub;

  // estado do sensores
  StreamSubscription<List<SensorData>>? _dataSub;
  List<SensorData> _sensorData = [];
  List<FlSpot> _temp = [];
  List<FlSpot> _hum = [];
  List<FlSpot> _lux = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _listenAdmin();
    _startListeningSensorData();
  }

  void _loadPermissions() {
    context.read<UserService>().myCropIds().then((list) {
      setState(() {
        _allowedList = list;
      });
    });
  }

  void _listenAdmin() {
    _adminSub = context.read<UserService>().isAdminStream.listen((isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
      });
    });
  }

  void _startListeningSensorData() {
    final ds = context.read<DataService>();

    _dataSub = ds
        .lastHourSensorDataStream(widget.crop.id, widget.crop.type)
        .listen((data) {
      setState(() {
        _sensorData = data;
        _temp = [];
        _hum = [];
        _lux = [];

        for (var i = 0; i < data.length; i++) {
          _temp.add(FlSpot(i.toDouble(), data[i].temperature));
          _hum.add(FlSpot(i.toDouble(), data[i].moisture));
          _lux.add(FlSpot(i.toDouble(), data[i].light));
        }
      });
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowedList == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isAssigned = _allowedList!.contains(widget.crop.id);

    if (!isAssigned && !_isAdmin) {
      return _deny();
    }

    // ---- Page UI ----
    return Scaffold(
      appBar: AppBar(title: Text('Crop • ${widget.crop.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${widget.crop.type}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Expanded(
              child: _sensorData.isEmpty
                  ? const Center(child: Text('No sensor data yet'))
                  : Stack(
                children: [
                  LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: _calculateMaxY(),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: (_sensorData.length / 4)
                                .ceilToDouble()
                                .clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final idx = value.round();
                              if (idx < 0 || idx >= _sensorData.length) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  DateFormat.Hm().format(
                                      _sensorData[idx].timestamp),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _calculateIntervalY(),
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
                          horizontalInterval: _calculateIntervalY()),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        _bar(_temp, Colors.redAccent),
                        _bar(_hum, Colors.blueAccent),
                        _bar(_lux, Colors.amber),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 5,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Card(
                        elevation: 2,
                        color:
                        Theme.of(context).cardColor.withOpacity(0.9),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  label: 'Light', color: Colors.amber),
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
      ),
    );
  }

  // Helpers -----------------------------------------------------------

  LineChartBarData _bar(List<FlSpot> spots, Color c) => LineChartBarData(
    spots: spots,
    isCurved: true,
    barWidth: 2,
    color: c,
    dotData: FlDotData(show: false),
  );

  double _calculateMaxY() {
    if (_sensorData.isEmpty) return 10;
    final maxVal = [
      ..._sensorData.map((e) => e.temperature),
      ..._sensorData.map((e) => e.moisture),
      ..._sensorData.map((e) => e.light)
    ].reduce((a, b) => a > b ? a : b);
    return (maxVal * 1.1).clamp(10, double.infinity);
  }

  double _calculateIntervalY() {
    return (_calculateMaxY() / 5).roundToDouble();
  }

  Scaffold _deny() => Scaffold(
    appBar: AppBar(title: Text('Crop • ${widget.crop.name}')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Access Denied',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
