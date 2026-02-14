import 'package:flutter/material.dart';
import 'package:frontend/src/controllers/action_controller.dart'; // For RebootProgressState

class RebootProgressDialog extends StatelessWidget {
  final int totalMiners;
  final int totalBatches;
  final int batchDelay;
  final VoidCallback onCancel;
  final Stream<RebootProgressState> stream;

  const RebootProgressDialog({
    super.key,
    required this.totalMiners,
    required this.totalBatches,
    required this.batchDelay,
    required this.onCancel,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RebootProgressState>(
      stream: stream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        
        // Auto-close on complete? Or let the controller close it?
        // Usually dialogs are closed by the parent or by a button.
        // The controller logic `_executeStaggeredReboot` had `Navigator.of(context).pop()` at the end.
        // Here we just display state.

        final completed = state?.completedMiners ?? 0;
        final success = state?.successCount ?? 0;
        final fail = state?.failCount ?? 0;
        final progress = totalMiners > 0 ? completed / totalMiners : 0.0;
        final currentBatch = state?.currentBatch ?? 1;
        final isWaiting = state?.isWaiting ?? false;
        final countdown = state?.countdown ?? 0;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.restart_alt, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8),
              Text('Staggered Reboot'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Batch progress text
                Text(
                  isWaiting
                      ? 'Waiting ${countdown}s before next batch...'
                      : 'Executing batch $currentBatch of $totalBatches...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                SizedBox(height: 8),

                // Stats row
                Text(
                  '$completed / $totalMiners miners processed',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text('$success success', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 16),
                    if (fail > 0) ...[
                      Icon(Icons.error, size: 14, color: Colors.red),
                      SizedBox(width: 4),
                      Text('$fail failed', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (!(state?.isComplete ?? false))
              TextButton(
                onPressed: onCancel,
                child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              )
            else
               TextButton(
                onPressed: onCancel, // Reuse onCancel to close, or add a separate onDismiss
                child: Text('Close'),
              ),
          ],
        );
      },
    );
  }
}
