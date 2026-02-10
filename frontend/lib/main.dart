import 'package:flutter/material.dart';
import 'package:frontend/src/rust/frb_generated.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/widgets/control_panel.dart';
import 'package:frontend/src/widgets/miner_list_view.dart';
import 'package:frontend/src/widgets/settings_dialog.dart';
import 'package:frontend/src/widgets/status_bar.dart';

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
  
  // Search/Filter state
  String _searchQuery = '';
  bool _activeOnly = false;
  bool _warningsOnly = false;

  List<Miner> get _filteredMiners {
    return _miners.where((m) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = m.ip.toLowerCase().contains(q) ||
            (m.model?.toLowerCase().contains(q) ?? false) ||
            (m.stats.worker1?.toLowerCase().contains(q) ?? false) ||
            (m.stats.worker2?.toLowerCase().contains(q) ?? false) ||
            (m.stats.worker3?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }
      // Toggle filters
      if (_activeOnly && m.status != MinerStatus.active) return false;
      if (_warningsOnly && m.status != MinerStatus.warning) return false;
      return true;
    }).toList();
  }

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

  void _handleFilterChanged(String searchQuery, bool activeOnly, bool warningsOnly) {
    setState(() {
      _searchQuery = searchQuery;
      _activeOnly = activeOnly;
      _warningsOnly = warningsOnly;
    });
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMiners = _filteredMiners;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bit-Link Miner Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          ControlPanel(
            onScanComplete: _handleScanComplete,
            selectedMinerIps: _selectedMinerIps,
            onFilterChanged: _handleFilterChanged,
          ),
          Expanded(
            child: MinerListView(
              miners: filteredMiners,
              selectedIps: _selectedMinerIps,
              onSelectionChanged: _handleSelectionChanged,
            ),
          ),
          StatusBar(
            miners: filteredMiners,
            selectedCount: _selectedMinerIps.length,
          ),
        ],
      ),
    );
  }
}
