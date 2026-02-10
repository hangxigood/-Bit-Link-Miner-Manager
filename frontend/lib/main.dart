import 'package:flutter/material.dart';
import 'package:frontend/src/rust/frb_generated.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/widgets/scanner_control_panel.dart';
import 'package:frontend/src/widgets/miner_list_view.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bit-Link Miner Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MinerDashboard(),
    );
  }
}

class MinerDashboard extends StatefulWidget {
  const MinerDashboard({super.key});

  @override
  State<MinerDashboard> createState() => _MinerDashboardState();
}

class _MinerDashboardState extends State<MinerDashboard> {
  List<Miner> _miners = [];
  List<String> _selectedMinerIps = [];

  void _handleScanComplete(List<dynamic> miners) {
    setState(() {
      _miners = miners.cast<Miner>();
    });
  }

  void _handleSelectionChanged(List<String> selectedIps) {
    setState(() {
      _selectedMinerIps = selectedIps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bit-Link Miner Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          ScannerControlPanel(onScanComplete: _handleScanComplete),
          Expanded(
            child: MinerListView(
              miners: _miners,
              selectedIps: _selectedMinerIps,
              onSelectionChanged: _handleSelectionChanged,
            ),
          ),
        ],
      ),
    );
  }
}
