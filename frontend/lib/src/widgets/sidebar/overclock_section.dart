import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

class OverclockSection extends StatefulWidget {
  final Function(String) onShowToast;

  const OverclockSection({super.key, required this.onShowToast});

  @override
  State<OverclockSection> createState() => _OverclockSectionState();
}

class _OverclockSectionState extends State<OverclockSection> {
  bool _enabled = false;
  String _model = 'S19 Pro';
  String _profile = 'Stock';

  final List<String> _models = ['S19 Pro', 'S19 XP', 'S21', 'M30S++'];
  final List<String> _profiles = [
    'Stock',
    'Low Power -10%',
    'High Perf +15%',
    'Maximum +25%',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.speed, size: 16, color: context.mutedText),
            SizedBox(width: 6),
            Text(
              'Overclock Settings',
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
                  widget.onShowToast('Overclock not implemented yet');
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        
        if (_enabled) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _model,
                  decoration: InputDecoration(
                    labelText: 'Model',
                    labelStyle: TextStyle(fontSize: 10),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  items: _models.map((model) {
                    return DropdownMenuItem(
                      value: model,
                      child: Text(model, style: TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _model = value!),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _profile,
                  decoration: InputDecoration(
                    labelText: 'Profile',
                    labelStyle: TextStyle(fontSize: 10),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  items: _profiles.map((profile) {
                    return DropdownMenuItem(
                      value: profile,
                      child: Text(profile, style: TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _profile = value!),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
