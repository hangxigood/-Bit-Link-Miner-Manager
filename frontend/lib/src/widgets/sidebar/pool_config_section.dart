import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/models.dart';
import 'package:frontend/src/theme/app_theme.dart';

class PoolConfigSection extends StatefulWidget {
  final Function(String) onShowToast;

  const PoolConfigSection({super.key, required this.onShowToast});

  @override
  State<PoolConfigSection> createState() => PoolConfigSectionState();
}

class PoolConfigSectionState extends State<PoolConfigSection> {
  // Pool 1
  bool _pool1Enabled = true;
  final _pool1UrlController = TextEditingController();
  final _pool1WorkerController = TextEditingController();
  final _pool1PasswordController = TextEditingController();

  // Pool 2
  bool _pool2Enabled = false;
  final _pool2UrlController = TextEditingController();
  final _pool2WorkerController = TextEditingController();
  final _pool2PasswordController = TextEditingController();

  // Pool 3
  bool _pool3Enabled = false;
  final _pool3UrlController = TextEditingController();
  final _pool3WorkerController = TextEditingController();
  final _pool3PasswordController = TextEditingController();

  /// Returns the list of enabled pools as [PoolConfig] objects.
  /// Returns null if no pools are enabled or pool 1 URL is empty.
  List<PoolConfig>? getEnabledPools() {
    final pools = <PoolConfig>[];

    if (_pool1Enabled && _pool1UrlController.text.trim().isNotEmpty) {
      pools.add(PoolConfig(
        url: _pool1UrlController.text.trim(),
        worker: _pool1WorkerController.text.trim(),
        password: _pool1PasswordController.text.trim().isEmpty
            ? 'x'
            : _pool1PasswordController.text.trim(),
      ));
    }

    if (_pool2Enabled && _pool2UrlController.text.trim().isNotEmpty) {
      pools.add(PoolConfig(
        url: _pool2UrlController.text.trim(),
        worker: _pool2WorkerController.text.trim(),
        password: _pool2PasswordController.text.trim().isEmpty
            ? 'x'
            : _pool2PasswordController.text.trim(),
      ));
    }

    if (_pool3Enabled && _pool3UrlController.text.trim().isNotEmpty) {
      pools.add(PoolConfig(
        url: _pool3UrlController.text.trim(),
        worker: _pool3WorkerController.text.trim(),
        password: _pool3PasswordController.text.trim().isEmpty
            ? 'x'
            : _pool3PasswordController.text.trim(),
      ));
    }

    return pools.isEmpty ? null : pools;
  }

  @override
  void dispose() {
    _pool1UrlController.dispose();
    _pool1WorkerController.dispose();
    _pool1PasswordController.dispose();
    _pool2UrlController.dispose();
    _pool2WorkerController.dispose();
    _pool2PasswordController.dispose();
    _pool3UrlController.dispose();
    _pool3WorkerController.dispose();
    _pool3PasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.dns, size: 16, color: context.mutedText),
            SizedBox(width: 6),
            Text(
              'Pool Configuration',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Pool 1
        _buildPoolCard(
          poolNumber: 1,
          isPrimary: true,
          enabled: _pool1Enabled,
          onEnabledChanged: (value) => setState(() => _pool1Enabled = value ?? false),
          urlController: _pool1UrlController,
          workerController: _pool1WorkerController,
          passwordController: _pool1PasswordController,
        ),
        
        SizedBox(height: 8),
        
        // Pool 2
        _buildPoolCard(
          poolNumber: 2,
          isPrimary: false,
          enabled: _pool2Enabled,
          onEnabledChanged: (value) => setState(() => _pool2Enabled = value ?? false),
          urlController: _pool2UrlController,
          workerController: _pool2WorkerController,
          passwordController: _pool2PasswordController,
        ),
        
        SizedBox(height: 8),
        
        // Pool 3
        _buildPoolCard(
          poolNumber: 3,
          isPrimary: false,
          enabled: _pool3Enabled,
          onEnabledChanged: (value) => setState(() => _pool3Enabled = value ?? false),
          urlController: _pool3UrlController,
          workerController: _pool3WorkerController,
          passwordController: _pool3PasswordController,
        ),
      ],
    );
  }

  Widget _buildPoolCard({
    required int poolNumber,
    required bool isPrimary,
    required bool enabled,
    required ValueChanged<bool?> onEnabledChanged,
    required TextEditingController urlController,
    required TextEditingController workerController,
    required TextEditingController passwordController,
  }) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.secondarySurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Checkbox(
                value: enabled,
                onChanged: onEnabledChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(width: 6),
              Text(
                'Pool $poolNumber',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (isPrimary) ...[
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Primary',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          SizedBox(height: 8),
          
          // Stratum URL
          TextField(
            controller: urlController,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: 'stratum+tcp://pool.example.com:3333',
              hintStyle: TextStyle(fontSize: 10),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
          
          SizedBox(height: 6),
          
          // Worker and Password
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: workerController,
                  enabled: enabled,
                  decoration: InputDecoration(
                    hintText: 'Worker/SubAccount',
                    hintStyle: TextStyle(fontSize: 10),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: TextStyle(fontSize: 10),
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: passwordController,
                  enabled: enabled,
                  decoration: InputDecoration(
                    hintText: 'Password (default: x)',
                    hintStyle: TextStyle(fontSize: 10),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: TextStyle(fontSize: 10),
                  obscureText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
