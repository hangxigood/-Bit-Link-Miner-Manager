import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';

import 'package:frontend/src/models/data_column_config.dart';

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

  void _setAll(bool visible) {
    setState(() {
      for (var i = 0; i < _columns.length; i++) {
        _columns[i] = _columns[i].copyWith(visible: visible);
      }
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
                buildDefaultDragHandles: false,
                itemCount: _columns.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final col = _columns[index];
                  return Material(
                    key: ValueKey(col.id),
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onToggle(index, !col.visible),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(
                          children: [
                            // Drag handle - ensure specific touch area
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_indicator, color: context.mutedText),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Label
                            Expanded(
                              child: Text(
                                col.label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            // Checkbox
                            Checkbox(
                              value: col.visible,
                              onChanged: (val) => _onToggle(index, val),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => _setAll(true),
                  child: Text('Show All', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => _setAll(false),
                  child: Text('Hide All', style: TextStyle(fontSize: 12)),
                ),
                Spacer(),
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
