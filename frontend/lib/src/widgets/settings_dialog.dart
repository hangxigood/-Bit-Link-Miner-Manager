import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';
import 'package:frontend/src/rust/api/settings.dart';
import 'package:frontend/src/rust/core/config.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Credentials
  final _antminerUserCtrl = TextEditingController();
  final _antminerPassCtrl = TextEditingController();
  final _whatsminerUserCtrl = TextEditingController();
  final _whatsminerPassCtrl = TextEditingController();
  bool _obscureAntminerPass = true;
  bool _obscureWhatsminerPass = true;

  bool _isLoading = true;
  
  // General settings
  double _scanThreadCount = 32;
  double _monitorInterval = 30;
  
  // Alert settings (Local only for now, or could be part of AppSettings eventually)
  bool _tempAlertsEnabled = false;
  double _tempThreshold = 85;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _antminerUserCtrl.dispose();
    _antminerPassCtrl.dispose();
    _whatsminerUserCtrl.dispose();
    _whatsminerPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = getAppSettings();
      
      if (mounted) {
        setState(() {
          _antminerUserCtrl.text = settings.antminerCredentials.username;
          _antminerPassCtrl.text = settings.antminerCredentials.password;
          _whatsminerUserCtrl.text = settings.whatsminerCredentials.username;
          _whatsminerPassCtrl.text = settings.whatsminerCredentials.password;
          
          _scanThreadCount = settings.scanThreadCount.toDouble();
          _monitorInterval = settings.monitorInterval.toDouble();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final settings = AppSettings(
      antminerCredentials: MinerCredentials(
        username: _antminerUserCtrl.text,
        password: _antminerPassCtrl.text,
      ),
      whatsminerCredentials: MinerCredentials(
        username: _whatsminerUserCtrl.text,
        password: _whatsminerPassCtrl.text,
      ),
      scanThreadCount: _scanThreadCount.toInt(),
      monitorInterval: BigInt.from(_monitorInterval.toInt()),
    );

    try {
      saveAppSettings(settings: settings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text('Settings'),
          Spacer(),
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
      content: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SizedBox(
              width: 600,
              height: 450,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'General'),
                      Tab(text: 'Credentials'),
                      Tab(text: 'Alerts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGeneralTab(),
                        _buildCredentialsTab(),
                        _buildAlertsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Settings',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16),
          
          Text(
            'Scan Thread Count: ${_scanThreadCount.toInt()}',
            style: TextStyle(fontSize: 12),
          ),
          Slider(
            value: _scanThreadCount,
            min: 1,
            max: 64,
            divisions: 63,
            label: _scanThreadCount.toInt().toString(),
            onChanged: (value) {
              setState(() {
                _scanThreadCount = value;
              });
            },
          ),
          
          SizedBox(height: 16),
          
          Text(
            'Monitor Interval: ${_monitorInterval.toInt()} seconds',
            style: TextStyle(fontSize: 12),
          ),
          Slider(
            value: _monitorInterval,
            min: 5,
            max: 120,
            divisions: 23,
            label: '${_monitorInterval.toInt()}s',
            onChanged: (value) {
              setState(() {
                _monitorInterval = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCredentialSection(
            title: 'Antminer Credentials',
            description: 'Default credentials for Antminer devices.',
            userCtrl: _antminerUserCtrl,
            passCtrl: _antminerPassCtrl,
            obscurePass: _obscureAntminerPass,
            onToggleObscure: () {
              setState(() {
                _obscureAntminerPass = !_obscureAntminerPass;
              });
            },
          ),
          SizedBox(height: 24),
          Divider(),
          SizedBox(height: 24),
          _buildCredentialSection(
            title: 'Whatsminer Credentials',
            description: 'Default credentials for Whatsminer devices.',
            userCtrl: _whatsminerUserCtrl,
            passCtrl: _whatsminerPassCtrl,
            obscurePass: _obscureWhatsminerPass,
            onToggleObscure: () {
              setState(() {
                _obscureWhatsminerPass = !_obscureWhatsminerPass;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialSection({
    required String title,
    required String description,
    required TextEditingController userCtrl,
    required TextEditingController passCtrl,
    required bool obscurePass,
    required VoidCallback onToggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
        ),
        SizedBox(height: 16),
        TextField(
          controller: userCtrl,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        SizedBox(height: 12),
        TextField(
          controller: passCtrl,
          obscureText: obscurePass,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePass ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: onToggleObscure,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temperature Alerts',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              Switch(
                value: _tempAlertsEnabled,
                onChanged: (value) {
                  setState(() {
                    _tempAlertsEnabled = value;
                  });
                },
              ),
              SizedBox(width: 8),
              Text(
                'Enable temperature alerts',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Text(
            'Alert Threshold: ${_tempThreshold.toInt()}°C',
            style: TextStyle(fontSize: 12),
          ),
          Slider(
            value: _tempThreshold,
            min: 60,
            max: 100,
            divisions: 40,
            label: '${_tempThreshold.toInt()}°C',
            onChanged: _tempAlertsEnabled
                ? (value) {
                    setState(() {
                      _tempThreshold = value;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

