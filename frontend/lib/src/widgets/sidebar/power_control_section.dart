import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

class PowerControlSection extends StatefulWidget {
  final Function(String) onShowToast;

  const PowerControlSection({super.key, required this.onShowToast});

  @override
  State<PowerControlSection> createState() => _PowerControlSectionState();
}

class _PowerControlSectionState extends State<PowerControlSection> {
  bool _enabled = false;
  bool _lpmEnabled = false;
  bool _enhancedLpmEnabled = false;

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
              onChanged: (value) {
                setState(() => _enabled = value);
                if (value) {
                  widget.onShowToast('Power Control not implemented yet');
                }
              },
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
                Row(
                  children: [
                    Checkbox(
                      value: _lpmEnabled,
                      onChanged: (value) => setState(() => _lpmEnabled = value ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Low Power Mode (LPM)',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Checkbox(
                      value: _enhancedLpmEnabled,
                      onChanged: (value) => setState(() => _enhancedLpmEnabled = value ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Enhanced LPM',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
