import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

class DataColumnConfig {
  final String id;
  final String label;
  final bool visible;

  const DataColumnConfig({
    required this.id,
    required this.label,
    required this.visible,
  });

  DataColumnConfig copyWith({String? id, String? label, bool? visible}) {
    return DataColumnConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      visible: visible ?? this.visible,
    );
  }
}

class ColumnSettingsDialog extends StatefulWidget {
  final List<DataColumnConfig> currentColumns;
  final Function(List<DataColumnConfig>) onApply;
  final VoidCallback onReset;

  const ColumnSettingsDialog({
    super.key,
    required this.currentColumns,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<ColumnSettingsDialog> createState() => _ColumnSettingsDialogState();
}

class _ColumnSettingsDialogState extends State<ColumnSettingsDialog> {
  late List<DataColumnConfig> _columns;

  @override
  void initState() {
    super.initState();
    _columns = List.from(widget.currentColumns);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _columns.removeAt(oldIndex);
      _columns.insert(newIndex, item);
    });
  }

  void _onToggle(int index, bool? value) {
    if (value == null) return;
    setState(() {
      _columns[index] = _columns[index].copyWith(visible: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: 400,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Column Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20, color: context.mutedText),
                  onPressed: () {
                    widget.onReset();
                    Navigator.of(context).pop();
                  },
                  tooltip: 'Reset to Default',
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(color: context.border),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _columns.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final col = _columns[index];
                  return ListTile(
                    key: ValueKey(col.id),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.drag_indicator, color: context.mutedText),
                    ),
                    title: Text(col.label, style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Checkbox(
                      value: col.visible,
                      onChanged: (val) => _onToggle(index, val),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onApply(_columns);
                    Navigator.of(context).pop();
                  },
                  child: Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
