import 'package:flutter/material.dart';
import 'package:frontend/src/theme/app_theme.dart';
import 'package:frontend/src/widgets/settings_dialog.dart';

class HeaderBar extends StatefulWidget {
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleTheme;
  final int onlineCount;
  final int totalCount;
  final double totalHashrate;

  const HeaderBar({
    super.key,
    required this.onToggleSidebar,
    required this.onToggleTheme,
    required this.onlineCount,
    required this.totalCount,
    required this.totalHashrate,
  });

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: context.border, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left: Sidebar toggle
          IconButton(
            icon: Icon(Icons.menu, size: 20),
            onPressed: widget.onToggleSidebar,
            tooltip: 'Toggle sidebar',
            padding: EdgeInsets.all(8),
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 8),
          
          // App icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.memory, size: 16, color: Colors.white),
          ),
          SizedBox(width: 12),
          
          // Title + badge
          Text(
            'MineControl',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: context.mutedText, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'v1.0',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: context.mutedText,
              ),
            ),
          ),
          SizedBox(width: 4),
          
          // Subtitle
          Text(
            'Mining Fleet Manager',
            style: TextStyle(
              fontSize: 10,
              color: context.mutedText,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Vertical divider
          Container(
            width: 1,
            height: 24,
            color: context.border,
          ),
          
          SizedBox(width: 16),
          
          // Live stats - Online count
          Icon(
            Icons.wifi,
            size: 14,
            color: widget.onlineCount > 0 ? context.success : context.mutedText,
          ),
          SizedBox(width: 6),
          Text(
            '${widget.onlineCount} / ${widget.totalCount} online',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Total hashrate with pulsing dot
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(
                    0.5 + (_pulseController.value * 0.5),
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 6),
          Text(
            '${widget.totalHashrate.toStringAsFixed(1)} TH/s total',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          Spacer(),
          
          // Right side: Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              size: 18,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            padding: EdgeInsets.all(8),
            constraints: BoxConstraints(),
            style: IconButton.styleFrom(
              foregroundColor: context.mutedText,
            ),
          ),
          
          SizedBox(width: 8),
          
          // Export button
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export feature not implemented yet')),
              );
            },
            icon: Icon(Icons.download, size: 16),
            label: Text('Export'),
            style: TextButton.styleFrom(
              foregroundColor: context.mutedText,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size(0, 28),
            ),
          ),
          
          SizedBox(width: 8),
          
          // Settings
          IconButton(
            icon: Icon(Icons.settings, size: 18),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SettingsDialog(),
              );
            },
            tooltip: 'Settings',
            padding: EdgeInsets.all(8),
            constraints: BoxConstraints(),
            style: IconButton.styleFrom(
              foregroundColor: context.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
