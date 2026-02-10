import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

class PoolConfigSection extends StatefulWidget {
  final Function(String) onShowToast;

  const PoolConfigSection({super.key, required this.onShowToast});

  @override
  State<PoolConfigSection> createState() => _PoolConfigSectionState();
}

class _PoolConfigSectionState extends State<PoolConfigSection> {
  // Pool 1
  bool _pool1Enabled = true;
  final _pool1UrlController = TextEditingController();
  final _pool1WorkerController = TextEditingController();
  final _pool1PasswordController = TextEditingController();
  String _pool1WorkerSuffix = 'ip';

  // Pool 2
  bool _pool2Enabled = false;
  final _pool2UrlController = TextEditingController();
  final _pool2WorkerController = TextEditingController();
  final _pool2PasswordController = TextEditingController();
  String _pool2WorkerSuffix = 'ip';

  // Pool 3
  bool _pool3Enabled = false;
  final _pool3UrlController = TextEditingController();
  final _pool3WorkerController = TextEditingController();
  final _pool3PasswordController = TextEditingController();
  String _pool3WorkerSuffix = 'ip';

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
          workerSuffix: _pool1WorkerSuffix,
          onWorkerSuffixChanged: (value) => setState(() => _pool1WorkerSuffix = value),
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
          workerSuffix: _pool2WorkerSuffix,
          onWorkerSuffixChanged: (value) => setState(() => _pool2WorkerSuffix = value),
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
          workerSuffix: _pool3WorkerSuffix,
          onWorkerSuffixChanged: (value) => setState(() => _pool3WorkerSuffix = value),
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
    required String workerSuffix,
    required ValueChanged<String> onWorkerSuffixChanged,
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
                    hintText: 'Password',
                    hintStyle: TextStyle(fontSize: 10),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: TextStyle(fontSize: 10),
                  obscureText: true,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 6),
          
          // Worker Suffix radio group
          Text(
            'Worker Suffix:',
            style: TextStyle(fontSize: 10, color: context.mutedText),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              _buildRadioOption('IP', 'ip', workerSuffix, onWorkerSuffixChanged, enabled),
              SizedBox(width: 8),
              _buildRadioOption('No Change', 'no_change', workerSuffix, onWorkerSuffixChanged, enabled),
              SizedBox(width: 8),
              _buildRadioOption('Empty', 'empty', workerSuffix, onWorkerSuffixChanged, enabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onChanged,
    bool enabled,
  ) {
    final isSelected = currentValue == value;
    
    return InkWell(
      onTap: enabled ? () => onChanged(value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: currentValue,
            onChanged: enabled ? (v) => onChanged(v!) : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: enabled ? Theme.of(context).colorScheme.onSurface : context.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
