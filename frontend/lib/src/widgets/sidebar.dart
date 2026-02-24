import 'package:flutter/material.dart';
import 'package:frontend/src/rust/core/models.dart';
import 'package:frontend/src/theme/app_theme.dart';
import 'package:frontend/src/widgets/sidebar/ip_ranges_section.dart';
import 'package:frontend/src/widgets/sidebar/pool_config_section.dart';
import 'package:frontend/src/widgets/sidebar/power_control_section.dart';
import 'package:frontend/src/widgets/sidebar/overclock_section.dart';

class Sidebar extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onScanStart;
  final Function(List<Miner>) onScanComplete;
  final Function(String) onShowToast;
  final GlobalKey<IpRangesSectionState>? ipRangesSectionKey;
  final GlobalKey<PoolConfigSectionState>? poolConfigSectionKey;
  final GlobalKey<PowerControlSectionState>? powerControlSectionKey;

  const Sidebar({
    super.key,
    required this.isCollapsed,
    required this.onScanStart,
    required this.onScanComplete,
    required this.onShowToast,
    this.ipRangesSectionKey,
    this.poolConfigSectionKey,
    this.powerControlSectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isCollapsed ? 0 : 320,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: 320,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(color: context.border, width: 1),
              ),
            ),
            child: Visibility(
              visible: !isCollapsed,
              maintainState: true,
              child: ListView(
                padding: EdgeInsets.all(12),
                children: [
                  IpRangesSection(
                    key: ipRangesSectionKey,
                    onScanStart: onScanStart,
                    onScanComplete: onScanComplete,
                    onShowToast: onShowToast,
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, thickness: 1),
                  SizedBox(height: 12),
                  PoolConfigSection(
                    key: poolConfigSectionKey,
                    onShowToast: onShowToast,
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, thickness: 1),
                  SizedBox(height: 12),
                  PowerControlSection(
                    key: powerControlSectionKey,
                    onShowToast: onShowToast,
                  ),
                  SizedBox(height: 12),
                  Divider(height: 1, thickness: 1),
                  SizedBox(height: 12),
                  OverclockSection(onShowToast: onShowToast),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
