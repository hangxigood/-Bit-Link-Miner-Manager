import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

/// Power mode selection. Only LPM is supported via the Antminer HTTP API.
enum PowerMode { normal, lpm }

class PowerControlSection extends StatefulWidget {
  final Function(String) onShowToast;

  const PowerControlSection({super.key, required this.onShowToast});

  @override
  State<PowerControlSection> createState() => PowerControlSectionState();
}

class PowerControlSectionState extends State<PowerControlSection> {
  bool _enabled = false;
  PowerMode _mode = PowerMode.normal;

  /// Returns the selected power mode if power control is enabled, null otherwise.
  /// - `true`  → put miner into Low Power Mode (sleep)
  /// - `false` → restore normal operation
  /// - `null`  → power control not enabled (do nothing)
  bool? getPowerMode() {
    if (!_enabled) return null;
    return _mode == PowerMode.lpm;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.bolt, size: 16, color: context.mutedText),
            SizedBox(width: 6),
            Text(
              'Power Control',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Spacer(),
            Switch(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),

        if (_enabled) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.secondarySurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode',
                  style: TextStyle(fontSize: 10, color: context.mutedText),
                ),
                SizedBox(height: 6),
                _buildModeOption(
                  label: 'Normal',
                  subtitle: 'Full power — resume mining at full hashrate',
                  value: PowerMode.normal,
                ),
                SizedBox(height: 4),
                _buildModeOption(
                  label: 'Low Power Mode (LPM)',
                  subtitle: 'Reduced hashrate to save power. Miner reboots.',
                  value: PowerMode.lpm,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeOption({
    required String label,
    required String subtitle,
    required PowerMode value,
  }) {
    final isSelected = _mode == value;
    return InkWell(
      onTap: () => setState(() => _mode = value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Radio<PowerMode>(
            value: value,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9, color: context.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
