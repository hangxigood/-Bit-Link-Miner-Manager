
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/controllers/action_controller.dart';
import 'package:frontend/src/controllers/dashboard_controller.dart';
import 'package:frontend/src/services/column_service.dart';
import 'package:frontend/src/models/data_column_config.dart';
import 'package:frontend/src/rust/api/commands.dart';
import 'package:frontend/src/rust/api/models.dart';

// Mock ColumnService to avoid SharedPreferences dependency
class MockColumnService extends ColumnService {
  @override
  Future<List<DataColumnConfig>> loadColumnSettings() async => [];
  
  @override
  Future<void> saveColumnSettings(List<DataColumnConfig> columns) async {}
  
  @override
  List<DataColumnConfig> getDefaultColumns() => [];
}

// Mock DashboardController
class MockDashboardController extends DashboardController {
  MockDashboardController() : super(MockColumnService());
  
  final Set<String> _blinking = {};
  
  @override
  Set<String> get blinkingIps => _blinking;
  
  @override
  void updateBlinkStatus(String ip, bool isBlinking) {
    if (isBlinking) {
      _blinking.add(ip);
    } else {
      _blinking.remove(ip);
    }
  }
}

void main() {
  group('ActionController Locate Toggle', () {
    late MockDashboardController dashboardController;
    late ActionController actionController;
    late List<Map<String, dynamic>> commandLog;

    setUp(() {
      dashboardController = MockDashboardController();
      commandLog = [];
      
      actionController = ActionController(
        dashboardController: dashboardController,
        onShowToast: (_) {},
        executeBatchCommand: ({
          required targetIps, 
          required command, 
          credentials
        }) async {
          commandLog.add({
            'ips': targetIps,
            'command': command,
          });
          // Return success for all
          return targetIps.map((ip) => CommandResult(ip: ip, success: true)).toList();
        },
      );
    });

    test('should start blinking if no selected miners are blinking', () async {
      // Setup: None blinking
      final selected = ['192.168.1.10', '192.168.1.11'];
      
      await actionController.toggleLocate(selected);
      
      expect(commandLog.length, 1);
      expect(commandLog.first['command'], MinerCommand.blinkLed);
      expect(commandLog.first['ips'], selected);
    });

    test('should stop blinking if ANY selected miner is blinking', () async {
      // Setup: One is blinking
      dashboardController.updateBlinkStatus('192.168.1.10', true);
      
      final selected = ['192.168.1.10', '192.168.1.11'];
      
      await actionController.toggleLocate(selected);
      
      expect(commandLog.length, 1);
      expect(commandLog.first['command'], MinerCommand.stopBlink); // expect STOP
      expect(commandLog.first['ips'], selected);
    });
    
    test('should start blinking if selected miners are NOT blinking, even if others are', () async {
      // Setup: A non-selected miner is blinking
      dashboardController.updateBlinkStatus('192.168.1.99', true);
      
      final selected = ['192.168.1.10', '192.168.1.11'];
      
      await actionController.toggleLocate(selected);
      
      expect(commandLog.length, 1);
      expect(commandLog.first['command'], MinerCommand.blinkLed); // expect START
      expect(commandLog.first['ips'], selected);
    });
    
    test('should do nothing if no miners selected', () async {
      await actionController.toggleLocate([]);
      expect(commandLog.isEmpty, true);
    });
  });
}
