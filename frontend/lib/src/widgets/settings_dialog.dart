import 'package:flutter/material.dart';
import 'package:frontend/src/services/credentials_service.dart';
import 'package:frontend/src/theme/app_theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Credentials
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  bool _obscurePassword = true;
  
  // General settings
  double _scanThreadCount = 32;
  double _monitorInterval = 30;
  
  // Alert settings
  bool _tempAlertsEnabled = false;
  double _tempThreshold = 85;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCredentials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final username = await CredentialsService.getUsername();
    final password = await CredentialsService.getPassword();
    
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
      _isLoading = false;
    });
  }

  Future<void> _saveCredentials() async {
    await CredentialsService.setUsername(_usernameController.text);
    await CredentialsService.setPassword(_passwordController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetToDefaults() async {
    await CredentialsService.resetToDefaults();
    await _loadCredentials();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to default credentials (root/root)')),
      );
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
              height: 400,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'General'),
                      Tab(text: 'Alerts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGeneralTab(),
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
          onPressed: _saveCredentials,
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
          
          // Scan thread count slider
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
          
          // Monitor interval slider
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
          
          // Temp alerts toggle
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
          
          // Temp threshold slider
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
          
          SizedBox(height: 24),
          Divider(),
          SizedBox(height: 16),
          
          Text(
            'SSH Credentials',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Default credentials for accessing miner web interfaces and sending commands.',
            style: TextStyle(fontSize: 11, color: context.mutedText),
          ),
          SizedBox(height: 16),
          
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: 12),
          TextButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset to Defaults (root/root)'),
          ),
        ],
      ),
    );
  }
}

