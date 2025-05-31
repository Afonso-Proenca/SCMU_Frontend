import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class IrrigationSettingsPage extends StatefulWidget {
  const IrrigationSettingsPage({Key? key}) : super(key: key);

  @override
  State<IrrigationSettingsPage> createState() => _IrrigationSettingsPageState();
}

class _IrrigationSettingsPageState extends State<IrrigationSettingsPage> {
  double _min = 20, _max = 60;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final ds = context.read<DataService>();

    ds.getSettings().then((s) {
      final data = ds.getLastHourDataCache();
      setState(() {
        _min = s.moistMin;
        _max = s.moistMax;
        _loading = false;
      });
    });
  }

  Widget _buildMoistureChart(List<SensorData> data) {
    if (data.isEmpty) return const Text('No data to display');

    final spots = data.map((d) {
      final ms = d.timestamp.millisecondsSinceEpoch.toDouble();
      return FlSpot(ms, d.moisture);
    }).toList();

    final minX = spots.first.x;
    final maxX = spots.last.x;

    // format timestamp to h:min
    String formatTime(double timestamp) {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      return DateFormat.Hm().format(dt);
    }

    final labelCount = 4;
    final labelPositions = List.generate(labelCount, (i) {
      return minX + ((maxX - minX) / (labelCount - 1)) * i;
    });

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  const tolerance = 5000;
                  final isExactLabel = labelPositions.any((p) => (value - p).abs() < tolerance);

                  if (!isExactLabel) return const SizedBox.shrink();

                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        formatTime(value),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text('${value.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(),
              bottom: BorderSide(),
            ),
          ),
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final ds = context.read<DataService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Irrigation Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  StreamBuilder<List<SensorData>>(
                    stream: ds.lastHourSensorDataStream(),

                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return _buildMoistureChart(snapshot.data!);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Soil moisture min: ${_min.toStringAsFixed(0)} %'),
                  const SizedBox(height: 16),
                  Text('Soil moisture max: ${_max.toStringAsFixed(0)} %'),
                  Slider(
                    value: _max,
                    min: _min + 5,
                    max: 100,
                    divisions: 20,
                    label: _max.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _max = v),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      await ds.saveSettings(
                          IrrigationSettings(moistMin: _min, moistMax: _max));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved!')));
                    },
                    child: const Text('Save'),
                  )
                ],
              ),
            ),
    );
  }
}
